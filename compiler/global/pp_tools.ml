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
(* useful stuff for printing *)

open Format

let rec print_list_r_empty print po sep pf ff = function
  | [] -> ()
  | x::l ->
    fprintf ff "@[%s%a" po print x;
    List.iter (fprintf ff "%s@]@ @[%a" sep print) l;
    fprintf ff "%s@]" pf

let rec print_list_r print po sep pf ff = function
  | [] -> fprintf ff "@[%s%s@]" po pf
  | x :: l ->
      fprintf ff "@[%s%a" po print x;
      List.iter (fprintf ff "%s@]@ @[%a" sep print) l;
      fprintf ff "%s@]" pf

let rec print_list_l print po sep pf ff = function
  | [] -> fprintf ff "@[%s%s@]" po pf
  | x :: l ->
      fprintf ff "@[%s%a" po print x;
      List.iter (fprintf ff "@]@ @[%s%a" sep print) l;
      fprintf ff "%s@]" pf

let rec print_list_rb print po sep pf ff = function
  | [] -> fprintf ff "@[%s%s@]" po pf
  | x :: l ->
      fprintf ff "@[<2>%s%a" po print x;
      List.iter (fprintf ff "%s@]@ @[<2>%a" sep print) l;
      fprintf ff "%s@]" pf

let rec print_list_lb print po sep pf ff = function
  | [] -> fprintf ff "@[%s%s@]" po pf
  | x :: l ->
      fprintf ff "@[<2>%s%a@]" po print x;
      List.iter (fprintf ff "@]@ @[<2>%s%a" sep print) l;
      fprintf ff "%s@]" pf

let print_couple print1 print2 po sep pf ff (c1, c2) =
  fprintf ff "%s%a%s@ %a%s" po print1 c1 sep print2 c2 pf

let print_couple2 print1 print2 po sep1 sep2 pf ff (c1, c2) =
  fprintf ff "%s%a%s@ %s%a%s" po print1 c1 sep1 sep2 print2 c2 pf

let print_with_braces print po pf ff p = fprintf ff "%s%a%s" po print p pf

let print_opt print ff = function
  | None -> ()
  | Some(s) -> print ff s

let print_opt_magic print ff = function
  | None -> pp_print_string ff "Obj.magic ()"
  | Some(e) -> print ff e


let print_opt2 print sep ff = function
  | None -> ()
  | Some(s) -> fprintf ff "%s%a" sep print s

let print_record print ff r =
  fprintf ff "@[<hv2>%a@]" (print_list_rb print "{ "";"" }") r

let print_type_params ff pl =
  print_list_r_empty (fun ff s -> fprintf ff "'%s" s) "("","") " ff pl