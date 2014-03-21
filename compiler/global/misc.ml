(**************************************************************************)
(*                                                                        *)
(*  The Zelus Hybrid Synchronous Language                                 *)
(*  Copyright (C) 2012-2013                                               *)
(*                                                                        *)
(*  Timothy Bourke                                                        *)
(*  Marc Pouzet                                                           *)
(*                                                                        *)
(*  Universite Pierre et Marie Curie - Ecole normale superieure - INRIA   *)
(*                                                                        *)
(*   This file is distributed under the terms of the CeCILL-C licence     *)
(*                                                                        *)
(**************************************************************************)
(* useful stuff *)

(* version of the compiler *)
let version = "Zélus Hybrid Synchronous language"
let subversion = "0.6"
let date = DATE

let header_in_file =
  "The " ^ version ^ " compiler, version " ^ subversion ^ "\n\  (" ^ date ^ ")"

(* standard module *)
let pervasives_module = "Pervasives"
let standard_lib = STDLIB
let standard_lib = try Sys.getenv "ZLLIB" with Not_found -> standard_lib

(* list of modules initially opened *)
let default_used_modules = ref [pervasives_module]

(* load paths *)
let load_path = ref ([standard_lib])

let set_stdlib p =
  load_path := [p]
and add_include d =
  load_path := d :: !load_path;;

(* where is the standard library *)
let locate_stdlib () =
  let stdlib = try
    Sys.getenv "ZLLIB"
  with
    Not_found -> standard_lib in
  Printf.printf "%s\n" stdlib

let show_version () =
  Printf.printf "The %s compiler, version %s (%s)\n"
    version subversion date;
  locate_stdlib ()

(* sets the simulation node *)
let simulation_node = ref None
let set_simulation_node (n:string) = simulation_node := Some(n)
let simulated_name n = 
  match !simulation_node with | None -> false | Some(m) -> n = m

(* sets the checking flag *)
let number_of_checks = ref 0
let set_check (n: int) = number_of_checks := n

(* sampling the main loop on a real timer *)
let sampling_rate = ref 0
let set_sampling_rate f = sampling_rate := f

(* level of inlining *)
let inlining_level = ref 10
let set_inlining_level l = inlining_level := l

(* turn on the discrete zero-crossing detection *)
let dzero = ref false

(* other options of the compiler *)
let verbose = ref false
let print_types = ref false
let print_causality = ref false
let typeonly = ref false
let use_gtk = ref false
let no_causality = ref false
let causality = ref false
let no_initialisation = ref false

let compile_periods_into_discrete_counters = ref false

type hybrid_mode =
  | DeltadelayTuple
  | DeltadelayFun
  | InstantaneousTuple
  | InstantaneousFun
  | AllSynchronous

(* let hybrid_mode = ref DeltadelayFun *)
let hybrid_mode = ref DeltadelayTuple
(* the solver to instantiate *)
let solver_module = ref SOLVER
let set_solver s () = solver_module := s

let set_hybrid_mode s = 
  let v =
    if s = "dtuple"      then DeltadelayTuple
    else if s = "dfun"   then DeltadelayFun
    else if s = "ituple" then InstantaneousTuple
    else if s = "ifun"   then InstantaneousFun
    else if s = "allsync" then AllSynchronous
    else !hybrid_mode
  in
  hybrid_mode := v

let h_allsync = ref 0.01 (* fixed step for the all_synchronous hybrid mode*)
let set_h_allsync h = h_allsync := h

let string_of_hybrid_mode m =
  match m with
  | DeltadelayTuple    -> "deltadelay (tuples)"
  | DeltadelayFun      -> "deltadelay (functions)"
  | InstantaneousTuple -> "instantaneous (tuples)"
  | InstantaneousFun   -> "instantaneous (functions)"
  | AllSynchronous     -> "ODE converted in synchronous code"
 

(* variable creation *)
(* generating names *)
class name_generator =
  object
    val mutable counter = 0
    method name =
      counter <- counter + 1;
      counter
    method reset =
      counter <- 0
    method init i =
      counter <- i
  end

let symbol = new name_generator

(* association table with memoization *)
class name_assoc_table f =
  object
    val mutable counter = 0
    val mutable assoc_table: (int * string) list = []
    method name var =
      try
        List.assq var assoc_table
      with
        not_found ->
          let n = f counter in
          counter <- counter + 1;
          assoc_table <- (var,n) :: assoc_table;
          n
    method reset =
      counter <- 0;
      assoc_table <- []
  end

(* converting integers into variable names *)
(* variables are printed 'a, 'b *)
let int_to_letter bound i =
  if i < 26
  then String.make 1 (Char.chr (i+bound))
  else String.make 1 (Char.chr ((i mod 26) + bound)) ^ string_of_int (i/26)

let int_to_alpha i = int_to_letter 97 i

(* generic and non generic variables in the various type systems *)
let generic = -1
let notgeneric = 0
let maxlevel = max_int

let binding_level = ref 0
let top_binding_level () = !binding_level = 0

let push_binding_level () = binding_level := !binding_level + 1
let pop_binding_level () =
  binding_level := !binding_level - 1;
  assert (!binding_level > generic)
let reset_binding_level () = binding_level := 0

let optional f acc = function
  | None -> acc
  | Some x -> f acc x

let optional_unit f acc = function
  | None -> ()
  | Some x -> f acc x

let optional_map f = function
  | None -> None
  | Some(x) -> Some(f x)

let optional_get = function
  | Some x -> x
  | None   -> assert false

let rec iter f = function
  | [] -> []
  | x :: l -> let y = f x in y :: iter f l

let fold f l = List.rev (List.fold_left f [] l)

let from i =
  let rec fromrec acc i =
    match i with
    | 0 -> acc
    | _ -> fromrec ( i :: acc) (i - 1) in
  fromrec [] i


(** The data-structure to represent a state *)
module State =
  struct
    type 'a t = (* ' *)
        | Empty
        | Cons of 'a * 'a t
        | Pair of 'a t * 'a t
    let singleton x = Cons(x, Empty)
    let cons x s = Cons(x, s)
    let pair s1 s2 = 
      match s1, s2 with
        | (Empty, s) | (s, Empty) -> s
        | _ -> Pair(s1, s2)
    let empty = Empty
    let is_empty s = (s = empty)
    let rec fold f s acc = match s with
      | Empty -> acc
      | Cons(x, l) -> f x (fold f l acc)
      | Pair(l1, l2) -> fold f l1 (fold f l2 acc)
    let list acc s = fold (fun l ls -> l :: ls) s acc

    let cons_list xs s = List.fold_left (fun s x -> Cons (x, s)) s (List.rev xs)

    let rec map f s = match s with
      | Empty -> Empty
      | Cons(x, l) -> Cons(f x, map f l)
      | Pair(l1, l2) -> Pair(map f l1, map f l2)

    let rec iter f s = match s with
      | Empty -> ()
      | Cons(x, l) -> (f x; iter f l)
      | Pair(l1, l2) -> (iter f l1; iter f l2)

    let fprint_t fprint_v ff s =
      Format.fprintf ff "@[<hov>{@ ";
      iter (fun v -> Format.fprintf ff "%a@ " fprint_v v) s;
      Format.fprintf ff "}@]"

  end

(* error during the whole process *)
exception Error

module S = Set.Make (struct type t = string let compare = compare end)
module Env = Map.Make (struct type t = string let compare = compare end)
