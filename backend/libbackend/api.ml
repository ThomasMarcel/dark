open Core_kernel
open Libexecution
open Types
open Analysis_types

type oplist = Op.op list [@@deriving yojson]

type rpc_params = {ops : oplist} [@@deriving yojson]

type analysis_params =
  { tlids : tlid list
  ; latest404 : RuntimeT.time }
[@@deriving eq, show, yojson]

type execute_function_params =
  { tlid : tlid
  ; trace_id : RuntimeT.uuid
  ; caller_id : id
  ; args : RuntimeT.dval list
  ; fnname : string }
[@@deriving yojson]

type route_params =
  { space : string
  ; path : string
  ; modifier : string }
[@@deriving yojson]

let to_rpc_params (payload : string) : rpc_params =
  payload
  |> Yojson.Safe.from_string
  |> rpc_params_of_yojson
  |> Result.ok_or_failwith


let to_analysis_params (payload : string) : analysis_params =
  payload
  |> Yojson.Safe.from_string
  |> analysis_params_of_yojson
  |> Result.ok_or_failwith


let to_execute_function_params (payload : string) : execute_function_params =
  payload
  |> Yojson.Safe.from_string
  |> execute_function_params_of_yojson
  |> Result.ok_or_failwith


let to_route_params (payload : string) : route_params =
  payload
  |> Yojson.Safe.from_string
  |> route_params_of_yojson
  |> Result.ok_or_failwith


let causes_any_changes (ps : rpc_params) : bool =
  List.exists ~f:Op.has_effect ps.ops


(*------------------*)
(* Functions *)
(*------------------*)
type param_metadata =
  { name : string
  ; tipe : string
  ; block_args : string list
  ; optional : bool
  ; description : string }
[@@deriving yojson]

type function_metadata =
  { name : string
  ; parameters : param_metadata list
  ; description : string
  ; return_type : string
  ; infix : bool
  ; preview_execution_safe : bool
  ; deprecated : bool }
[@@deriving yojson]

let functions ~username =
  !Libs.static_fns
  |> String.Map.to_alist
  |> List.filter ~f:(fun (k, _) ->
         Account.can_access_operations username
         || not (String.is_prefix ~prefix:"DarkInternal::" k) )
  |> List.map ~f:(fun (k, (v : RuntimeT.fn)) ->
         { name = k
         ; parameters =
             List.map
               ~f:(fun p ->
                 ( { name = p.name
                   ; tipe = Dval.tipe_to_string p.tipe
                   ; block_args = p.block_args
                   ; optional = p.optional
                   ; description = p.description }
                   : param_metadata ) )
               v.parameters
         ; description = v.description
         ; return_type = Dval.tipe_to_string v.return_type
         ; preview_execution_safe = v.preview_execution_safe
         ; infix = List.mem ~equal:( = ) v.infix_names k
         ; deprecated = v.deprecated } )
  |> fun l ->
  `List (List.map ~f:function_metadata_to_yojson l)
  |> Yojson.Safe.pretty_to_string