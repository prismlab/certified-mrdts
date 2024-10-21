let debug_mode = true 
let debug_print fmt =
  if debug_mode then Printf.printf fmt
  else Printf.ifprintf stdout fmt

(* unique replica ID *)
type repId = int 

(* unique version number *)
type ver = repId * int (* replicaID, version number *)

(* conflict resolution type *)
type rc_res = 
  | Fst_then_snd
  | Snd_then_fst
  | Either

type state = int * bool (* counter, flag *)

module IntSet = Set.Make (struct
  type t = int
  let compare = compare
end)

module RepSet = Set.Make (struct
  type t = repId
  let compare = compare
end)

type op = 
  | Enable
  | Disable

(* event type *)
type event = int * repId * op (* timestamp, replicaID, operation *)
let get_ts ((t,_,_):event) = t

let init_st = (0, false)

let mrdt_do s e =
  match e with
  | _, _, Enable -> (fst s + 1, true)
  | _, _, Disable -> (fst s, false)

let merge_flag l a b =
  let lc = fst l in
  let ac = fst a in
  let bc = fst b in
  let af = snd a in
  let bf = snd b in
  if af && bf then true
    else if not af && not bf then false
      else if af then ac - lc > 0
        else bc - lc > 0

let mrdt_merge (l:state) (a:state) (b:state) : state =
  (fst a + fst b - fst l, merge_flag l a b)

let rc e1 e2 =
  let _,_,o1 = e1 in let _,_,o2 = e2 in
  match o1, o2 with
  | Enable, Disable -> Snd_then_fst
  | Disable, Enable -> Fst_then_snd
  | _ -> Either

let eq s1 s2 = 
  s1 = s2

let verNo = ref 1
let ts = ref 1

(* generates unique version numbers *)
let gen_ver (r:repId) =
  let v = !verNo in 
  incr verNo;           
  (r, v)

(* generates increasing timestamps *)
let gen_ts _ =
  let t = !ts in
  incr ts; 
  t

module VerSet = Set.Make (struct
  type t = ver
  let compare = compare
end)

module VisSet = Set.Make (struct
  type t = event * event
  let compare = compare
end)

module RepIdMap = Map.Make (struct
  type t = repId
  let compare = compare 
end)

module VerMap = Map.Make (struct
  type t = ver
  let compare = compare 
end)

(* Types of edges in the version graph *)
type edgeType = 
  | CreateBranch of repId * repId (* fork r2 from r1 *)
  | Apply of event (* apply op on the head version of r *)
  | Merge of repId * repId (* merge the head versions of r1 and r2 *)

(* edgeType in the version graph *)
type edge = { 
  src : ver;
  label : edgeType;
  dst : ver;
}

(* DAG *)
type dag = { 
  vertices : VerSet.t;   (* Set of active vertices *)
  edges : edge list;  (* List of edges *)
}

(* Configuration type *)
type config = {
  r : RepSet.t;            (* r is a set of active replicas *)
  n : state VerMap.t;      (* n maps versions to their states *)
  h : ver RepIdMap.t;      (* h maps replicas to their head version *)
  v : VerSet.t RepIdMap.t; (* v maps replicas to the set of versions in that replica *)
  l : event list VerMap.t; (* l maps a version to the list of MRDT events that led to this version *)
  g : dag;                 (* g is a version graph whose vertices represent the active versions 
                              and whose edges represent relationship between different versions. *)
  vis : VisSet.t           (* vis is a partial order over events *)
}

let commutes_with (s:state) (e1:event) (e2:event) : bool =
  let r = eq (mrdt_do (mrdt_do s e1) e2) (mrdt_do (mrdt_do s e2) e1) in
  assert (if r = true then (if rc e1 e2 = Either then true else false) 
          else (if rc e1 e2 <> Either then true else false));
  r

(* Add an edge to the graph *)
let add_edge (g:dag) (src:ver) (label:edgeType) (dst:ver) : dag = {
  vertices = VerSet.add src (VerSet.add dst g.vertices);
  edges = {src; label; dst}::g.edges;
}

let print_st (s:state) =
  debug_print "(%d,%b)" (fst s) (snd s)

let initNs : int = 0
let initR : RepSet.t = RepSet.add 0 RepSet.empty
let initN : state VerMap.t = VerMap.add (0,0) init_st VerMap.empty
let initH : ver RepIdMap.t = RepIdMap.add 0 (0,0) RepIdMap.empty
let initV : VerSet.t RepIdMap.t = RepIdMap.add 0 (VerSet.add (0,0) VerSet.empty) RepIdMap.empty
let initL : event list VerMap.t = VerMap.add (0,0) [] VerMap.empty
let initG : dag = { 
  vertices = VerSet.add (0,0) VerSet.empty;
  edges = []
}
let initVis : VisSet.t = VisSet.empty

(* Initial configuration *)
let init_config = {r = initR; n = initN; h = initH; v = initV; l = initL; g = initG; vis = initVis}

let apply_events el =
  let apply_events_aux (acc:state) (el:event list) : state =
    List.fold_left (fun acc e -> mrdt_do acc e) acc el in
  apply_events_aux init_st el

(* return value : (index, can_reorder) *)
let can_reorder (e:event) (l:event list) : (int * bool) =
  let rec can_reorder_aux (e:event) (l:event list) (acc:(int * bool)) : (int * bool) =
    match l with
    | [] -> acc
    | hd::tl -> if rc e hd = Fst_then_snd then (0, true)
                else if rc e hd = Snd_then_fst then (0, false)
                else 
                  begin match tl with
                  | [] -> can_reorder_aux e tl (fst acc + 1, snd acc)
                  | hd1::_ -> if commutes_with init_st hd hd1 then can_reorder_aux e tl (fst acc + 1, snd acc)
                              else (0, false)
                  end in
    can_reorder_aux e l (0, false)
              
let rec insert_at_index l ele i =
  match l, i with
  | [], _ -> [ele] 
  | _, 0 -> ele::l
  | hd::tl, n -> hd::insert_at_index tl ele (n - 1)

let rec linearize (l1:event list) (l2:event list) : event list =
  match (l1, l2) with
  | [], [] -> []
  | [], _ -> l2
  | _, [] -> l1
  | e1::tl1, e2::tl2 -> if rc e1 e2 = Fst_then_snd then 
                          (let l2' = linearize l1 tl2 in if not (List.mem e2 l2') then e2::l2' else l2')
                        else if rc e1 e2 = Snd_then_fst then 
                          (let l1' = linearize tl1 l2 in if not (List.mem e1 l1') then e1::l1' else l1')
                        else 
                          (let (i,b) = can_reorder e1 l2 in
                            if b = true then 
                              (let l2' = linearize l1 (insert_at_index tl2 e2 (i-1)) in
                                if not (List.mem (List.nth l2 i) l2') then (List.nth l2 i)::l2' else l2')
                            else 
                            (let (i,b) = can_reorder e2 l1 in
                              if b = true then 
                                (let l1' = linearize (insert_at_index tl1 e1 (i-1)) l2 in
                                  if not (List.mem (List.nth l1 i) l1') then (List.nth l1 i)::l1' else l1')
                              else 
                                (let l2' = linearize tl1 l2 in
                                if not (List.mem e1 l2') then e1::l2' else l2')))

let get_rids (c:config) : repId list =
  List.map fst (RepIdMap.bindings c.h)
  
(* Check linearization for a replica r *)                                
let lin_check (r:int) (c:config) =
  debug_print "\n\nTesting config with nv=%d" (VerSet.cardinal c.g.vertices);
  debug_print "\n\n***Testing linearization for R%d" r;
  debug_print "\nLin result = ";
  print_st (apply_events (List.rev (VerMap.find (RepIdMap.find r c.h) c.l)));
  debug_print "\nState = ";
  print_st (VerMap.find (RepIdMap.find r c.h) c.n);
  eq (apply_events (List.rev (VerMap.find (RepIdMap.find r c.h) c.l))) 
     (VerMap.find (RepIdMap.find r c.h) c.n)                            
          
let is_enable o =
  match o with
  | Enable -> true
  | _ -> false

let rem_dup lst =
  let rec rem_dup_aux seen lst =
    match lst with
    | [] -> List.rev seen 
    | hd :: tl ->
      if List.mem hd seen then rem_dup_aux seen tl 
      else rem_dup_aux (hd :: seen) tl 
  in
  rem_dup_aux [] lst

let read (r:repId) (c:config) =
  (VerMap.find (RepIdMap.find r c.h) c.n)

let sim (r:repId) (c:config) =
  let en_ev = List.filter (fun e -> let (_,_,o) = e in is_enable o) (VerMap.find (RepIdMap.find r c.h) c.l) in
  let dis_ev = List.filter (fun d -> let (_,_,o) = d in not (is_enable o)) (VerMap.find (RepIdMap.find r c.h) c.l) in
  let n = List.length en_ev in
  let f = List.exists (fun e -> (List.for_all (fun d -> not (VisSet.mem (e,d) c.vis)) dis_ev)) en_ev in
  (n, f) 

(* Check simulation relation *)
let sim_check (r:repId) (c:config) =
  let s = read r c in
  let abs = sim r c in
  debug_print "\n\nTesting config with nv=%d" (VerSet.cardinal c.g.vertices);
  debug_print "\n\n***Testing simulation relation for R%d" r;
  debug_print "\nAbs sim result = ";
  print_st (sim r c);
  debug_print "\nState = ";
  print_st (read r c);
  eq s abs  

(* BEGIN of helper functions to print the graph *)
let string_of_event ((t, r, o):event) =
  Printf.sprintf "(%d, %d, %s)" t r (if is_enable o then "Enable" else "Disable")

let str_of_edge = function
  | CreateBranch (r1, r2) -> Printf.sprintf "Fork r%d from r%d" r2 r1
  | Apply e -> string_of_event e
  | Merge (r1, r2) -> Printf.sprintf "Merge r%d into r%d" r2 r1

let print_edge e = 
  debug_print "\nv(%d,%d) --> [%s] --> v(%d,%d)" 
  (fst e.src) (snd e.src) (str_of_edge e.label) (fst e.dst) (snd e.dst)

let print_vertex (c:config) (v:ver) =
  match VerMap.find_opt v c.n with
  | Some st ->
      debug_print "\nv(%d,%d) => state:" (fst v) (snd v);
      print_st st
  | None ->
      debug_print "\nv(%d,%d) => state: not found!" (fst v) (snd v)

let print_dag (c:config) =
  debug_print "\n\nReplicas:\n";
  List.iter (fun r -> debug_print "r%d\n" r) (get_rids c);
  debug_print "\nVertices:";
  VerSet.iter (print_vertex c) c.g.vertices;
  debug_print "\n\nEdges:";
  List.iter print_edge (List.rev c.g.edges)

(* END of helper functions to print the graph *)

(* CreateBranch function *)
let createBranch (c:config) (srcRid:repId) (dstRid:repId) : config =
  let newVer = gen_ver dstRid in
  if srcRid = dstRid then failwith "CreateBranch: Destination replica must be different from source replica";
  if List.mem dstRid (get_rids c) then failwith (Printf.sprintf "CreateBranch: Destination replica (r%d) is already forked" dstRid);
  if VerSet.mem newVer c.g.vertices then failwith "CreateBranch: New version already exists in the configuration";
  let srcVer = RepIdMap.find srcRid c.h in
  let newR = RepSet.add dstRid c.r in
  let newN = VerMap.add newVer (VerMap.find srcVer c.n) c.n in
  let newH = RepIdMap.add dstRid newVer c.h in
  let newV = RepIdMap.add dstRid (RepIdMap.find srcRid c.v) c.v in
  let newL = VerMap.add newVer (VerMap.find srcVer c.l) c.l in
  let newG = add_edge c.g srcVer (CreateBranch (srcRid, dstRid)) newVer in
  let new_c = {r = newR; n = newN; h = newH; v = newV; l = newL; g = newG; vis = c.vis} in
  print_dag new_c;
  (*debug_print "\nLinearization check for createBranch started.";*)
  assert (lin_check dstRid new_c); 
  assert (sim_check dstRid new_c);
  (*debug_print "\nLinearization check for createBranch successful.";*)
  debug_print "\n******************************************";
  new_c

(* Apply function *)
let apply (c:config) (srcRid:repId) (o:event) : config = 
  let newVer = gen_ver srcRid in
  if VerSet.mem newVer c.g.vertices then failwith "Apply: New version already exists in the configuration";

  let srcVer = RepIdMap.find srcRid c.h in
  let newN = VerMap.add newVer (mrdt_do (VerMap.find srcVer c.n) o) c.n in
  let newH = RepIdMap.add srcRid newVer c.h in
  let newV = RepIdMap.add srcRid (VerSet.add newVer (RepIdMap.find srcRid c.v)) c.v in
  let newL = VerMap.add newVer (o::VerMap.find srcVer c.l) c.l in
  let newG = add_edge c.g srcVer (Apply o) newVer in
  let newVis = List.fold_left (fun acc o1 -> VisSet.add (o1,o) acc) c.vis (VerMap.find srcVer c.l) in
  let new_c = {r = c.r; n = newN; h = newH; v = newV; l = newL; g = newG; vis = newVis} in
  print_dag new_c;
  (*debug_print "\nLinearization check for apply started...";*)
  assert (lin_check srcRid new_c); 
  assert (sim_check srcRid new_c);
  (*debug_print "\nLinearization check for apply successful.";*)
  debug_print "\n******************************************";
  new_c

(* Check if path exists between v1 and v2 *)
let path_exists (e:edge list) (v1:ver) (v2:ver) : bool =
  let rec path_exists_aux (e:edge list) (visited:VerSet.t) (v1:ver) (v2:ver) : bool =
    if v1 = v2 then true
    else
      let visited = VerSet.add v1 visited in
      let neighbors = List.fold_left (fun acc e ->
        if e.src = v1 && not (VerSet.mem e.dst visited) then e.dst :: acc else acc) [] e in
      List.exists (fun n -> path_exists_aux e visited n v2) neighbors in
  path_exists_aux e VerSet.empty v1 v2

(* Find potential LCAs. ca is candidate LCAs set *)
let potential_lca (e:edge list) (v1:ver) (v2:ver) (ca:VerSet.t) : VerSet.t = 
  (*Checks if a candidate LCA v' is not reachable to another version in ca *)
  let is_lca (v:ver) : bool = (* Ln 38 of the appendix *)
    not (VerSet.exists (fun v' -> path_exists e v' v1 && path_exists e v' v2 && path_exists e v v') (VerSet.remove v ca)) in
  
    VerSet.filter (fun v' -> path_exists e v' v1 && path_exists e v' v2 && is_lca v') ca

(* Find the ancestors of a given version *)
let rec find_ancestors (d:dag) (v:ver) : VerSet.t =
  (*if not (version_exists d.vertices v) then failwith "Version does not exist in the graph";*)
  List.fold_left (fun acc edge -> 
    if edge.dst = v then VerSet.union acc (VerSet.add edge.src (find_ancestors d edge.src))
    else acc) (VerSet.add v VerSet.empty) d.edges

let no_path_exists (vs:VerSet.t) (e:edge list) : bool =
  VerSet.for_all (fun v ->
    VerSet.for_all (fun v' ->
      if v = v' then true else not (path_exists e v v' || path_exists e v' v)) vs) vs
    
let rec recursive_merge (c:config) (pa:VerSet.t) : (VerSet.t * config) =
  if VerSet.cardinal pa = 1 then (pa, c)
  else 
    let v1 = VerSet.choose pa in
    let v2 = VerSet.choose (VerSet.remove v1 pa) in
    let s1 = VerMap.find v1 c.n in 
    let s2 = VerMap.find v2 c.n in
    let newVer = gen_ver (fst v1) in
    let (lca, _) = find_lca c v1 v2 in
    match lca with
    | None -> failwith "LCA not found"
    | Some vl -> 
      let sl = VerMap.find vl c.n in
      let m = mrdt_merge sl s1 s2 in
      let newN = VerMap.add newVer m (VerMap.add vl sl c.n) in
      let newH = RepIdMap.add (fst v1) newVer c.h in
      let newL = c.l in (* didn't change linearization *)
      let newG = add_edge (add_edge c.g (RepIdMap.find (fst v1) c.h) (Merge (fst v1, fst v2)) newVer) (RepIdMap.find (fst v2) c.h) (Merge (fst v1, fst v2)) newVer in
      let new_config = {c with n = newN; h = newH; l = newL; g = newG} in
      let new_pa = VerSet.add newVer (VerSet.remove v1 (VerSet.remove v2 pa)) in
      recursive_merge new_config new_pa

(* Find LCA function *)
and find_lca (c:config) (v1:ver) (v2:ver) : (ver option * config) =
  let a1 = find_ancestors c.g v1 in
  let a2 = find_ancestors c.g v2 in
  let ca = VerSet.inter a1 a2 in (* common ancestors *)
  let pa = potential_lca c.g.edges v1 v2 ca in (* potential LCAs *)
  if VerSet.is_empty pa then (None, c) 
  else 
    (debug_print "\nPotential LCAs of (%d,%d) and (%d,%d) are:" (fst v1) (snd v1) (fst v2) (snd v2);
    VerSet.iter (fun v -> debug_print "(%d,%d)" (fst v) (snd v)) pa; 
    assert (no_path_exists pa c.g.edges); (* checks if not path exists between any 2 distinct vertices in pa *)
    let lca_set, new_config = recursive_merge c pa in
    assert (VerSet.cardinal lca_set = 1); (* checks if there is only one LCA *)
    (Some (VerSet.choose lca_set), new_config))

(* Merge function *)
let merge (c:config) (r1:repId) (r2:repId) : config =
  let newVer = gen_ver r1 in
  if VerSet.mem newVer c.g.vertices then failwith "Merge: New version already exists in the configuration";

  let v1 = RepIdMap.find r1 c.h in 
  let v2 = RepIdMap.find r2 c.h in 
  let s1 = VerMap.find v1 c.n in 
  let s2 = VerMap.find v2 c.n in 
  let lca_v, new_config = find_lca c v1 v2 in
  match lca_v with
    | None -> failwith "lCA is not found"
    | Some vl -> let sl = VerMap.find vl new_config.n in  
                 let m = mrdt_merge sl s1 s2 in
  let newN = VerMap.add newVer m c.n in
  let newH = RepIdMap.add r1 newVer c.h in
  let newV = RepIdMap.add r1 (VerSet.add newVer (VerSet.union (RepIdMap.find r1 c.v) (RepIdMap.find r2 c.v))) c.v in
  let newL = VerMap.add newVer (linearize (VerMap.find (RepIdMap.find r1 c.h) c.l) (VerMap.find (RepIdMap.find r2 c.h) c.l)) c.l in
  let newG = let e = add_edge c.g (RepIdMap.find r1 c.h) (Merge (r1, r2)) newVer in
             add_edge e (RepIdMap.find r2 c.h) (Merge (r1, r2)) newVer in
  let new_c = {r = c.r; n = newN; h = newH; v = newV; l = newL; g = newG; vis = c.vis} in
  print_dag new_c;
  (*debug_print "\nLinearization check for merge started.";*)
  (*assert (lin_check r1 new_c); *)
  assert (sim_check r1 new_c);
  (*debug_print "\nLinearization check for merge successful.";*)
  debug_print "\n******************************************";
  new_c

(* Get vertices set from edge list *)
let vertices_from_edges (el:edge list) : VerSet.t =
  List.fold_left (fun acc e -> VerSet.add e.src (VerSet.add e.dst acc)) VerSet.empty el

let print_linearization (el:event list) =
  debug_print "\nLinearized Events:\n";
  List.iter (fun e -> debug_print "%s\n" (string_of_event e)) el

(* change the function linearize that takes two list of events
as input and outputs a list of events to the following:
1. first if two list are empty, output is empty
2. if one of the lists is empty, the result is the other list
3. If both lists are non-empty, 
    let e1 and e2 are the last events in l1 and l2.
    if rc e1 e2 = Fst_then_snd, then e2::(linearize l1 (tail l2)
    else if rc e1 e2 = Snd_then_fst, then e1::(linearize (tail l1) l2)
    else (* both are related by Either *)
        i. find if there exists an e3 in (l2\e2) such that (rc e1 e3 = Fst_then_snd &&
                  e3 commutes with all the events in the list which is formed
                  from the events following e3 till the end of l2) then e3::(linearize l1 (place e2 where e3 was present originally in (l2\e2)))
        ii. if not such e3 exists in l2 check for the same property as given in i for e2 and l1
        iii. if not such e3 exists in l1 then e1::(linearize (l1\e1) l2) )*)
