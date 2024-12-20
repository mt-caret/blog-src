open! Core
open! Import
open Command.Param

let input_file = anon ("INPUT_FILE" %: Filename_unix.arg_type)
let input_dir = anon ("INPUT_DIR" %: Filename_unix.arg_type)
let output_file = anon ("OUTPUT_FILE" %: Filename_unix.arg_type)
let output_dir = anon ("OUTPUT_DIR" %: Filename_unix.arg_type)
let git_revision = flag "git-revision" (required string) ~doc:"STRING Git revision"

let git_revision_file =
  flag
    "git-revision-file"
    (required Filename_unix.arg_type)
    ~doc:"PATH Path to git revision file"
;;

let template_file =
  flag "template" (required Filename_unix.arg_type) ~doc:"PATH Path to template file"
;;
