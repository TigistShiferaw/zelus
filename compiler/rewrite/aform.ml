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
(* A-normal form: distribution of tuples *)
(* for any variable [x: t1 *...* t2n, introduce fresh names *)
(* [x1:t1,...,xn:tn] so that [x = (x1,...,xn)] *)
(* distribute pattern matchings [(p1,...,pn) = (e1,...,en)] into *)
(* p1 = e1 and ... pn = en] *)
open Zelus

(* matching. Translate [(p1,...,pn) = (e1,...,en)] into the set of *)
(* equations [p1 = e1 and ... and pn = en] *)
(* [compose] defines the type of equation: [init p = e] or [p = e] or [next p = e] *)
let rec matching compose eq_list p e =
  match p.p_desc, e.e_desc with
    | Etuplepat(p_list), Etuple(e_list) ->
        matching_list compose eq_list p_list e_list
    | _ -> { eq_desc = compose p e; eq_loc = e.e_loc } :: eq_list

and matching_list compose eq_list p_list e_list =
  List.fold_left2 (matching compose) eq_list p_list e_list

let rec equation eq_list ({ eq_desc = desc } as eq) =
  match desc with
    | EQeq(pat, e) -> 
        matching (fun p e -> EQeq(p, e)) eq_list pat e
    | EQnext(pat, e, None) -> 
        matching (fun p e -> EQnext(p, e, None)) eq_list pat e
    | EQinit(pat, e0, None) ->
        matching (fun p e -> EQinit(p, e, None)) eq_list pat e0
    | EQmatch(total, e, m_h_list) ->
        { eq with eq_desc = EQmatch(total, e, 
				    List.map handler m_h_list) } :: eq_list
    | _ -> eq :: eq_list

and equation_list eq_list = List.fold_left equation [] eq_list

and handler ({ m_body = b } as m_h) = { m_h with m_body = block b }

and block ({ b_body = eq_list } as b) = { b with b_body = equation_list eq_list }

let exp e =
  match e.e_desc with
    | Elet(({ l_eq = eq_list } as l), e) ->
        { e with e_desc = Elet({ l with l_eq = equation_list eq_list }, e) }
    | _ -> e

let implementation impl =
  match impl.desc with
    | Eopen _ | Etypedecl _ -> impl
    | Econstdecl(n, e) -> { impl with desc = Econstdecl(n, exp e) }
    | Efundecl(n, ({ f_body = e } as body)) ->
        { impl with desc = Efundecl(n, { body with f_body = exp e }) }

let implementation_list impl_list = Misc.iter implementation impl_list
