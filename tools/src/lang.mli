(** A blog post's natural language. The set is closed; add a constructor to support a new
    language. Language and translation pairing are derived from a post's slug (filename):
    [foo] is English, [foo.ja] is its Japanese version. *)

open! Core

type t =
  | English
  | Japanese
[@@deriving sexp_of, equal]

val all : t list
val default : t

(** ISO code used for [<html lang>] and [hreflang] (e.g. ["en"], ["ja"]). *)
val code : t -> string

(** Human-readable name shown in the "also available in" link (e.g. ["日本語"]). *)
val label : t -> string

(** Splits a slug into its language and its translation base (the slug shared by all
    language versions). [of_slug "foo"] is [English, "foo"]; [of_slug "foo.ja"] is
    [Japanese, "foo"]. Unrecognized suffixes default to [default]. *)
val of_slug : string -> t * string
