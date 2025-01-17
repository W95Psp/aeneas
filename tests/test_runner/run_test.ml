(* Paths to use for tests *)
type runner_env = {
  charon_path : string;
  aeneas_path : string;
  llbc_dir : string;
  dest_dir : string;
}

let concat_path = List.fold_left Filename.concat ""

module Command = struct
  type t = { args : string array; redirect_out : Unix.file_descr option }
  type status = Success | Failure

  let make (args : string list) : t =
    { args = Array.of_list args; redirect_out = None }

  let to_string (cmd : t) = Core.String.concat_array ~sep:" " cmd.args

  (* Run the command and returns its exit status. *)
  let run (cmd : t) : status =
    let command_str = to_string cmd in
    print_endline ("[test_runner] Running: " ^ command_str);

    (* Run the command *)
    let out = Option.value cmd.redirect_out ~default:Unix.stdout in
    let pid = Unix.create_process cmd.args.(0) cmd.args Unix.stdin out out in
    let status = Core_unix.waitpid (Core.Pid.of_int pid) in
    match status with
    | Ok () -> Success
    | Error (`Exit_non_zero _) -> Failure
    | Error (`Signal _) ->
        failwith ("Command `" ^ command_str ^ "` exited incorrectly.")

  (* Run the command and aborts the program if the command failed. *)
  let run_command_expecting_success cmd =
    match run cmd with
    | Success -> ()
    | Failure -> failwith ("Command `" ^ to_string cmd ^ "` failed.")

  (* Run the command and aborts the program if the command succeeded. *)
  let run_command_expecting_failure cmd =
    match run cmd with
    | Success ->
        failwith
          ("Command `" ^ to_string cmd ^ "` succeeded but was expected to fail.")
    | Failure -> ()
end

(* Run Aeneas on a specific input with the given options *)
let run_aeneas (env : runner_env) (case : Input.t) (backend : Backend.t) =
  let backend_str = Backend.to_string backend in
  let input_file = concat_path [ env.llbc_dir; case.name ] ^ ".llbc" in
  let output_file =
    Filename.remove_extension case.path ^ "." ^ backend_str ^ ".out"
  in
  let per_backend = Backend.Map.find backend case.per_backend in
  let subdir = per_backend.subdir in
  let check_output = per_backend.check_output in
  let aeneas_options = per_backend.aeneas_options in
  let action = per_backend.action in
  let dest_dir = concat_path [ env.dest_dir; backend_str; subdir ] in

  (* Build the command *)
  let args =
    [ env.aeneas_path; input_file; "-dest"; dest_dir; "-backend"; backend_str ]
  in
  let abort_on_error =
    match action with
    | Skip | Normal -> []
    | KnownFailure -> [ "-abort-on-error" ]
  in
  let args = List.concat [ args; aeneas_options; abort_on_error ] in
  let cmd = Command.make args in
  (* Remove leftover files if they're not needed anymore *)
  if
    Sys.file_exists output_file
    &&
    match action with
    | Skip | Normal -> true
    | KnownFailure when not check_output -> true
    | _ -> false
  then Sys.remove output_file;
  (* Run Aeneas *)
  match action with
  | Skip -> ()
  | Normal -> Command.run_command_expecting_success cmd
  | KnownFailure ->
      let out =
        if check_output then
          Core_unix.openfile ~mode:[ O_CREAT; O_TRUNC; O_WRONLY ] output_file
        else Core_unix.openfile ~mode:[ O_WRONLY ] "/dev/null"
      in
      let cmd = { cmd with redirect_out = Some out } in
      Command.run_command_expecting_failure cmd;
      Unix.close out

(* Run Charon on a specific input with the given options *)
let run_charon (env : runner_env) (case : Input.t) =
  match case.kind with
  | SingleFile ->
      let args =
        [
          env.charon_path;
          "--no-cargo";
          "--input";
          case.path;
          "--crate";
          case.name;
          "--dest";
          env.llbc_dir;
        ]
      in
      let args = List.append args case.charon_options in
      (* Run Charon on the rust file *)
      Command.run_command_expecting_success (Command.make args)
  | Crate -> (
      match Sys.getenv_opt "IN_CI" with
      | None ->
          let args =
            [ env.charon_path; "--dest"; Filename_unix.realpath env.llbc_dir ]
          in
          let args = List.append args case.charon_options in
          (* Run Charon inside the crate *)
          let old_pwd = Unix.getcwd () in
          Unix.chdir case.path;
          Command.run_command_expecting_success (Command.make args);
          Unix.chdir old_pwd
      | Some _ ->
          (* Crates with dependencies must be generated separately in CI. We skip
             here and trust that CI takes care to generate the necessary llbc
             file. *)
          print_endline
            "Warn: IN_CI is set; we skip generating llbc files for whole crates"
      )

let () =
  match Array.to_list Sys.argv with
  (* Ad-hoc argument passing for now. *)
  | _exe_path :: charon_path :: aeneas_path :: llbc_dir :: test_path
    :: aeneas_options ->
      let runner_env =
        { charon_path; aeneas_path; llbc_dir; dest_dir = "tests" }
      in
      let test_case = Input.build test_path in
      let test_case =
        {
          test_case with
          per_backend =
            Backend.Map.map
              (fun x ->
                {
                  x with
                  Input.aeneas_options =
                    List.append aeneas_options x.Input.aeneas_options;
                })
              test_case.per_backend;
        }
      in
      let skip_all =
        List.for_all
          (fun backend ->
            (Backend.Map.find backend test_case.per_backend).action = Input.Skip)
          Backend.all
      in
      if skip_all then ()
      else (
        (* Generate the llbc file *)
        run_charon runner_env test_case;
        (* Process the llbc file for the each backend *)
        List.iter (run_aeneas runner_env test_case) Backend.all)
  | _ -> failwith "Incorrect options passed to test runner"
