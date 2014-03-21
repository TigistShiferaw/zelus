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
(* read an interface *)

open Location
open Lident
open Zelus
open Global
open Deftypes
open Modules
open Types
open Format

(* types of errors *)
type error =
    | Eunbound_type_constr of Lident.t
    | Etype_constr_arity of Lident.t * int * int
    | Eunbound_type_var of string
    | Erepeated_type_param of string
    | Erepeated_constructor of string
    | Erepeated_label of string
    | Ealready_defined_type of string
    | Ealready_defined_constr of string
    | Ealready_defined_label of string
    | Ealready_defined_value of string
    | Ecyclic_abbreviation

exception Error of location * error

let error loc e = raise(Error(loc, e))

(* printing error messages *)
let message loc kind =
  begin match kind with
    | Eunbound_type_constr(longname) ->
        eprintf "%aThe type constructor %s is unbound.@."
          output_location loc (modname longname)
    | Etype_constr_arity(longname, arit, arit') ->
        eprintf "%aThe type constructor %s expects %d argument(s),\
                     but is here given %d argument(s).@."
        output_location loc
          (modname longname) arit arit'
    | Eunbound_type_var(n) ->
        eprintf "%aThe type variable %s is unbound.@."
          output_location loc
          n
    | Erepeated_type_param(n) ->
        eprintf "%aRepeated parameter in type declaration.@."
          output_location loc
    | Erepeated_constructor(n) ->
        eprintf "%aTwo constructors are named %s@."
          output_location loc n
    | Erepeated_label(n) ->
        eprintf "%aTwo labels are named %s@."
          output_location loc n
    | Ealready_defined_type(n) ->
        eprintf "%aThe type %s already exists in the current module.@."
          output_location loc n
    | Ealready_defined_constr(n) ->
        eprintf
          "%aThe constructor %s already exists in the current module.@."
          output_location loc n
    | Ealready_defined_label(n) ->
        eprintf "%aThe label %s already exists in the current module.@."
          output_location loc n
    | Ealready_defined_value(n) ->
        eprintf "%aThe value %s already exists in the current module.@."
          output_location loc n
    | Ecyclic_abbreviation ->
        eprintf "%aThis definition is cyclic.@."
        output_location loc
  end;
  raise Misc.Error

let make desc = { desc = desc; loc = no_location }

(* type checking of type declarations *)
let global n desc = { qualid = Modules.qualify n; info = desc }

let rec free_of_type v ty =
  match ty.desc with
    | Etypevar(x) -> if List.mem x v then v else x::v
    | Etypetuple(t) ->
        List.fold_left free_of_type v t
    | Etypeconstr(_,t) ->
        List.fold_left free_of_type v t

(* checks that every type is defined *)
(* and used with the correct arity *)
let constr_name loc s arity =
  let { qualid = name; info = desc } =
    try
      Modules.find_type s
    with
      | Not_found -> error loc (Eunbound_type_constr(s)) in
  let arity' = List.length desc.type_parameters in
    if arity' <> arity
    then error loc (Etype_constr_arity(s, arity', arity));
  name

let kindtype = function
  | A -> Tany | C -> Tcont | AD -> Tdiscrete(false) | D -> Tdiscrete(true)

let kindoftype = function
  | Tany -> A | Tcont -> C | Tdiscrete(s) -> if s then D else AD

let typ_of_type_expression typ_vars typ =
  let rec typrec typ =
    match typ.desc with
      | Etypevar(s) ->
          begin try
              List.assoc s typ_vars
            with
                Not_found -> error typ.loc (Eunbound_type_var(s))
          end
      | Etypetuple(l) ->
          Types.product (List.map typrec l)
      | Etypeconstr(s, ty_list) ->
                let name = constr_name typ.loc s (List.length ty_list) in
            Types.nconstr name (List.map typrec ty_list)
  in typrec typ

let rec type_expression_of_typ typ =
  match typ.t_desc with
    | Tvar -> make (Etypevar("'a" ^ (string_of_int typ.t_index)))
    | Tproduct(l) ->
        make (Etypetuple(List.map type_expression_of_typ l))
    | Tconstr(s, ty_list, _) ->
        make (Etypeconstr(Modules.currentname (Lident.Modname(s)),
                         List.map type_expression_of_typ ty_list))
    | Tlink(typ) -> type_expression_of_typ typ

(* translate the internal representation of a type into a type definition *)
let type_decl_of_type_desc tyname
    { type_desc = ty_desc; type_parameters = ty_param } =
  (* variant types *)
  let variant_type { qualid = qualid } = Modules.shortname qualid in
  (* record types *)
  let record_type { qualid = qualid; info = { label_arg = arg } } =
    Modules.shortname qualid, type_expression_of_typ arg in

  let params = List.map (fun i -> "'a" ^ (string_of_int i)) ty_param in
  let type_decl =
    match ty_desc with
      | Abstract_type -> Eabstract_type
      | Variant_type(c_list) -> Evariant_type(List.map variant_type c_list)
      | Record_type(l_list) -> Erecord_type(List.map record_type l_list)
      | Abbrev(_, ty) -> Eabbrev(type_expression_of_typ ty) in
  (tyname, params, type_decl)


(* translating a declared signature into an internal type *)
let scheme_of_type_signature 
    { sig_inputs = typ_i_list; sig_output = typ_o; 
      sig_kind = k; sig_safe = s } =
  let lv = List.fold_left free_of_type [] typ_i_list in
  let lv = free_of_type lv typ_o in
  let typ_vars = List.map (fun v -> (v, new_generic_var ())) lv in
  let typ_i_list = 
    List.map (typ_of_type_expression typ_vars) typ_i_list in
  let typ_o = typ_of_type_expression typ_vars typ_o in
  { typ_vars = List.map snd typ_vars; 
    typ_body = Tsignature(kindtype k, s, typ_i_list, typ_o) }


(* translating a declared type into an internal type *)
let scheme_of_type typ =
  let lv = free_of_type [] typ in
  let typ_vars = List.map (fun v -> (v, new_var ())) lv in
  let typ = typ_of_type_expression typ_vars typ in
  { typ_vars = List.map snd typ_vars;
    typ_body = Tvalue(typ) }

(* analysing a type declaration *)
let check_no_repeated_type_param loc typ_params =
  let rec checkrec tp =
    match tp with
      | [] -> ()
      | x :: tp ->
          if List.mem x tp then error loc (Erepeated_type_param(x))
          else checkrec tp in
    checkrec typ_params

let check_no_repeated_constructor loc l =
  let rec checkrec cont l =
    match l with
      | [] -> ()
      | s :: l ->
          if List.mem s cont  then error loc (Erepeated_constructor(s))
          else checkrec (s :: cont) l in
    checkrec [] l

let check_no_repeated_label loc l =
  let rec checkrec cont l =
    match l with
        [] -> ()
      | (s,_) :: l ->
          if List.mem s cont then error loc (Erepeated_label(s))
          else checkrec (s :: cont) l in
    checkrec [] l

(* typing type definitions *)
let type_variant_type typ_vars constr_decl_list final_typ =
  let type_one_variant constr_decl =
    global constr_decl { constr_res = final_typ } in
  List.fold_left
    (fun l constr_decl -> (type_one_variant constr_decl) :: l)
    [] constr_decl_list

let type_record_type typ_vars label_type_list final_typ =
  let type_one_label (s, typ_expr) =
    let typ_arg = typ_of_type_expression typ_vars typ_expr in
    (global s { label_arg = final_typ; label_res = typ_arg }) in
    List.fold_left (fun l one_label -> (type_one_label one_label) :: l)
      [] label_type_list

(* first makes an initial type environnement *)
let make_initial_typ_environment loc typ_name typ_params =
    check_no_repeated_type_param loc typ_params;
    let typ_desc = { type_parameters = List.map (fun _ -> 0) typ_params;
                     type_desc = Abstract_type } in
    try
      add_type typ_name typ_desc;
      global typ_name typ_desc
    with
      | Already_defined(name) ->
          error loc (Ealready_defined_type name)

let type_one_typedecl loc gtype (typ_name, typ_params, typ) =
  let typ_vars = List.map (fun v -> (v, new_generic_var ())) typ_params in
  let final_typ =
    Types.nconstr (Modules.qualify typ_name)
      (List.map (fun v -> List.assoc v typ_vars) typ_params) in

  let type_desc =
    match typ with
      | Eabstract_type -> Abstract_type
      | Eabbrev(ty) ->
          Abbrev(List.map (fun (_, v) -> v) typ_vars,
                typ_of_type_expression typ_vars ty)
      | Evariant_type constr_decl_list ->
          check_no_repeated_constructor loc constr_decl_list;
          let l = type_variant_type typ_vars constr_decl_list final_typ in
            (* add the list of constructors to the symbol table *)
            begin try
                List.iter (fun g -> add_constr g.qualid.id g.info) l;
              Variant_type l
              with
                | Modules.Already_defined (name) ->
                    error loc (Ealready_defined_constr name)
            end
      | Erecord_type label_decl_list ->
          check_no_repeated_label loc label_decl_list;
          let l = type_record_type typ_vars label_decl_list final_typ in
            (* add the list of record fields to the symbol table *)
            begin try
                List.iter (fun g -> add_label g.qualid.id g.info) l;
              Record_type l
              with
                | Modules.Already_defined (name) ->
                    error loc (Ealready_defined_label name)
            end
  in

    (* modify the description associated to the declared type *)
    gtype.info.type_desc <- type_desc;
    gtype.info.type_parameters <-
      List.map (fun (_, ty) -> Deftypes.index ty) typ_vars;
    gtype

(* the main functions *)
let typedecl ff loc ty_name ty_params typ =
  try
    let gtype = make_initial_typ_environment loc ty_name ty_params in
    let gtype = type_one_typedecl loc gtype (ty_name, ty_params, typ) in
    if !Misc.print_types then
      Ptypes.output_type_declaration ff [gtype]
  with
    | Error(loc, k) -> message loc k

(* analysing a value declaration *)
let addvalue ff loc name is_atomic ty_scheme =
  try
    add_value name (value_desc is_atomic ty_scheme);
    if !Misc.print_types then
      Ptypes.output_value_type_declaration ff [global name ty_scheme]
  with
    | Already_defined(x) -> message loc (Ealready_defined_value(x))

(* adding the type signature for a constant and a function. By default *)
(* [is_atomic = true] meaning that no inlining should be necessary to compile *)
(* the callees *)
let constdecl ff loc name typ =
  addvalue ff loc name true (scheme_of_type typ)

let fundecl ff loc name sig_typ =
  addvalue ff loc name true (scheme_of_type_signature sig_typ)

let interface ff inter =
  match inter.desc with
    | Einter_open(modname) -> Modules.open_module modname
    | Einter_typedecl(name, params, typ) ->
        typedecl ff inter.loc name params typ
    | Einter_constdecl(x, typ) ->
        constdecl ff inter.loc x typ
    | Einter_fundecl(x, sig_typ) ->
        fundecl ff inter.loc x sig_typ

let interface_list ff p_list =
  try
    List.iter (interface ff) p_list
  with Error (loc, err) -> message loc err
 