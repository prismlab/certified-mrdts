module App_do_pre_ret

open SeqUtils
module L = FStar.List.Tot

#set-options "--query_stats"
let rec mem_id_s (id:pos) (l:list (pos * nat))
    : Tot (b:bool {b = true <==> (exists m. L.mem (id,m) l) /\ (exists e. L.mem e l ==> fst e = id)}) =
  match l with
  |[] -> false
  |(id1,m)::xs -> id = id1 || mem_id_s id xs

let rec unique_s (l:list (pos * nat)) =
  match l with
  |[] -> true
  |(id,m)::xs -> not (mem_id_s id xs) && unique_s xs

let rec idx (id:pos * nat) (l:list (pos * nat) {L.mem id l /\ unique_s l}) : Tot nat =
  match l with
  |id1::xs -> if id = id1 then 0 else 1 + idx id xs

//increasing order
let rec total_order (l:list (pos * nat) {unique_s l}) : prop =
  match l with
  |[] -> true
  |[x] -> true
  |x::xs ->  (forall e. L.mem e xs ==> lt (fst x) (fst e)) /\  total_order xs

let ord (id:(pos * nat)) (id1:(pos * nat) {fst id <> fst id1})
        (l:list (pos * nat) {L.mem id l /\ L.mem id1 l /\ unique_s l /\ total_order l})
        : Tot (b:bool {b = true <==> idx id l < idx id1 l})
    = idx id l < idx id1 l 
    
// the concrete state type
// It is a sequence of pairs of timestamp and message.
// As the sequence is sorted based on timestamps we ignore the message
type concrete_st = l:list (pos & nat){unique_s l /\ total_order l}

// init state
let init_st = []

// equivalence between 2 concrete states
let eq (a b:concrete_st) =
  a == b

// few properties of equivalence relation
let symmetric (a b:concrete_st) 
  : Lemma (requires eq a b)
          (ensures eq b a) = ()

let transitive (a b c:concrete_st)
  : Lemma (requires eq a b /\ eq b c)
          (ensures eq a c) = ()

let eq_is_equiv (a b:concrete_st)
  : Lemma (requires a == b)
          (ensures eq a b) = ()

// operation type
type app_op_t:eqtype = 
  | Enqueue : nat -> app_op_t
  | Dequeue

type ret_t:eqtype = option (pos * nat)

let return (s:concrete_st) (o:op_t) : ret_t =
  match o with
  |(_, (Enqueue _,_)) -> None
  |(_, (Dequeue,_)) -> if L.length s = 0 then None else Some (L.hd s)

let do_pre_client (s:concrete_st) (op:op_t) =
  (forall id. mem_id_s id s ==> id < fst op)

#push-options "--z3rlimit 50"
let rec append (s1 s2:list (pos * nat)) 
  : Tot (r:list (pos * nat){forall id. mem_id_s id r <==> mem_id_s id s1 \/ mem_id_s id s2}) (decreases %[s1;s2]) =
  match s1, s2 with
  |[],[] -> []
  |[],_ -> s2
  |_,[] -> s1
  |x::xs,_ -> x::append xs s2

let rec lem_append (s1 s2:concrete_st)
  : Lemma (requires (forall id id1. mem_id_s id s1 /\ mem_id_s id1 s2 ==> id < id1))
          (ensures unique_s (append s1 s2) /\ total_order (append s1 s2))
          (decreases %[s1;s2]) =
  match s1, s2 with
  |[],[] -> ()
  |[],_ -> ()
  |_,[] -> ()
  |x::xs,_ -> lem_append xs s2

// apply an operation to a state
let do (s:concrete_st) (op:op_t{do_pre s op}) : concrete_st =
  match op with
  |(id, (Enqueue x,_)) -> lem_append s [(id, x)];
                          append s [(id, x)]
  |(_, (Dequeue,_)) -> if L.length s = 0 then s else L.tl s

let lem_do (a b:concrete_st) (op:op_t)
   : Lemma (requires eq a b /\ do_pre a op)
           (ensures eq (do a op) (do b op)) = ()

let extract (o:op_t{Dequeue? (fst (snd o)) /\ Some? (ret_of o)}) : (pos * nat) =
  let (_, (_, Some x)) = o in x
  
//conflict resolution
let resolve_conflict (x:op_t) (y:op_t{fst x <> fst y}) : resolve_conflict_res =
  match x, y with
  |(_,(Enqueue _,_)), (_,(Enqueue _,_)) -> if fst x < fst y then Second_then_first else First_then_second
  |_, (_,(Dequeue,None)) -> Noop_second
  |(_,(Dequeue,None)), _ -> Noop_first
  |(_,(Dequeue,None)), (_,(Dequeue,None)) -> Noop_both
  |(_,(Enqueue _,_)), (_,(Dequeue,Some _)) -> Second_then_first
  |(_,(Dequeue,Some _)), (_,(Enqueue _,_)) -> First_then_second 
  |(_,(Dequeue,Some _)), (_,(Dequeue,Some _)) -> if fst (extract x) = fst (extract y) then First 
                                                 else if fst (extract x) < fst (extract y) then First_then_second
                                                      else Second_then_first

let rec diff_s (a l:concrete_st)
  : Tot (r:concrete_st{(forall e. L.mem e r <==> (L.mem e a /\ not (L.mem e l)))}) =
  match a with
  |[] -> []
  |x::xs -> if L.mem x l then diff_s xs l else x::diff_s xs l
  
let merge_pre (l a b:concrete_st) : prop =
  (*(forall e e1. (L.mem e a /\ L.mem e1 l /\ (fst e = fst e1)) ==> (snd e = snd e1)) /\
  (forall e e1. (L.mem e b /\ L.mem e1 l /\ (fst e = fst e1)) ==> (snd e = snd e1)) /\
  (forall e e1. (L.mem e l /\ L.mem e1 l /\ L.mem e a /\ L.mem e1 a /\ ord e e1 l) ==> ord e e1 a) /\
  (forall e e1. (L.mem e l /\ L.mem e1 l /\ L.mem e b /\ L.mem e1 b /\ ord e e1 l) ==> ord e e1 b) /\*)
  (forall id. mem_id_s id l ==> not (mem_id_s id (diff_s a l)) /\ not (mem_id_s id (diff_s b l))) /\ 
  (forall id. mem_id_s id (diff_s a l) ==> not (mem_id_s id (diff_s b l)))

let rec intersection (l a b:concrete_st) 
  : Tot (i:concrete_st{(forall e. L.mem e i <==> L.mem e a /\ L.mem e b /\ L.mem e l)}) =
  match l with
  |[] -> []
  |x::xs -> if L.mem x a && L.mem x b then x::intersection xs a b else intersection xs a b

#push-options "--z3rlimit 100 --fuel 1"
let rec union_s (a:concrete_st) (b:concrete_st)
  : Pure concrete_st
    (requires (forall id. mem_id_s id a ==> not (mem_id_s id b)))
    (ensures (fun u -> (forall e. L.mem e u <==> L.mem e a \/ L.mem e b) /\
                    (forall id. mem_id_s id u <==> mem_id_s id a \/ mem_id_s id b))) =
  match a, b with
  |[], [] -> []
  |[], _ -> b
  |_, [] -> a
  |h1::t1, h2::t2 -> if lt (fst h1) (fst h2) then h1::(union_s t1 b) else h2::(union_s a t2)
#pop-options

let concrete_merge (l a:concrete_st) (b:concrete_st{merge_pre l a b}) 
  : (r:concrete_st{(forall e. L.mem e r <==> (L.mem e l /\ L.mem e a /\ L.mem e b) \/ L.mem e (diff_s a l) \/ L.mem e (diff_s b l))}) =
  let i = intersection l a b in
  let diff_a = diff_s a l in
  let diff_b = diff_s b l in
  let union_ab = union_s diff_a diff_b in
  let res = union_s i union_ab in
  res

let rec remove_ele (ele:(pos * nat)) (a:concrete_st)
  : Pure concrete_st
    (requires (L.mem ele a))
    (ensures (fun r -> (forall e. L.mem e r <==> L.mem e a /\ e <> ele) /\ not (mem_id_s (fst ele) r) /\
                    (forall id. mem_id_s id r <==> mem_id_s id a /\ id <> fst ele) /\
                    (forall e e1. L.mem e r /\ L.mem e1 r /\ ord e e1 r /\ lt (fst e) (fst e1) <==>
                    L.mem e a /\ L.mem e1 a /\ e <> ele /\ e1 <> ele /\ lt (fst e) (fst e1) /\ ord e e1 a))) =
  match a with
  |ele1::xs -> if ele = ele1 then xs else ele1::(remove_ele ele xs)

let rec lem_equal (a b:concrete_st) 
  : Lemma (requires (forall e. L.mem e a <==> L.mem e b))  
          (ensures (List.Tot.length a = List.Tot.length b) /\
                   (a = b)) =
  let rec lem_len (a b:concrete_st) 
    : Lemma (requires (forall e. L.mem e a <==> L.mem e b))
            (ensures (List.Tot.length a = List.Tot.length b)) =
  begin
  match a,b with
  |[],[] -> ()
  |x::xs,_ -> lem_len xs (remove_ele x b)
  |[],_ -> ()
  end in

  
  begin 
  lem_len a b;
  match a,b with
  |[],[] -> ()
  |x::xs, y::ys -> lem_equal xs ys
  end

// Prove that merge is commutative
let merge_is_comm (lca s1 s2:st)
  : Lemma (requires consistent_branches lca s1 s2 /\
                    merge_pre (v_of lca) (v_of s1) (v_of s2))
          (ensures merge_pre (v_of lca) (v_of s2) (v_of s1) /\
                   (eq (concrete_merge (v_of lca) (v_of s1) (v_of s2)) 
                       (concrete_merge (v_of lca) (v_of s2) (v_of s1)))) =
  lem_equal (concrete_merge (v_of lca) (v_of s1) (v_of s2))
            (concrete_merge (v_of lca) (v_of s2) (v_of s1))           
                       
let linearizable_s1_0''_base_base (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2' = ops_of lca /\
                    length (ops_of lca) = 0 /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2))
        
          (ensures eq (do (v_of s2') last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2))) =
  lem_equal (do (v_of s2') last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2))

let tl_lt (hd:(pos & nat)) (a:concrete_st) (ts:pos)
  : Lemma (requires (forall id. mem_id_s id a ==> lt id ts) /\
                    (forall id. mem_id_s id a ==> lt (fst hd) id))
          (ensures (forall id. mem_id_s id (hd::a) ==> lt id ts)) = 
  admit()

let linearizable_s1_0''_base_do_pre (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\ 
                    consistent_branches lca s1 (do_st s2' last2) /\
                    ops_of s1 == ops_of lca /\ ops_of s2' == ops_of lca /\
                    fst last2 > 0 /\
                    length (ops_of s2') > 0)
          (ensures do_pre (v_of (inverse_st s2')) last2) = 
  let pre, lastop = un_snoc (ops_of s2') in
  lem_apply_log init_st (ops_of s2');
  if Enqueue? (fst (snd lastop)) then () 
  else 
    (if return (v_of (inverse_st s2')) lastop = None then () 
     else tl_lt (L.hd (v_of (inverse_st s2'))) (v_of s2') (fst last2))

let linearizable_s1_0''_base_merge_pre (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\ 
                    consistent_branches lca s1 (do_st s2' last2) /\
                    ops_of s1 == ops_of lca /\ ops_of s2' == ops_of lca /\
                    fst last2 > 0 /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2) /\
                    length (ops_of s2') > 0 /\
                    do_pre (v_of (inverse_st s2')) last2)

          (ensures (let l' = inverse_st lca in
                    merge_pre (v_of l') (v_of l') (do (v_of l') last2))) = 
  let pre, lastop = un_snoc (ops_of s2') in
  lem_apply_log init_st (ops_of s2');
  if Enqueue? (fst (snd lastop)) then () 
  else 
    (if return (v_of (inverse_st s2')) lastop = None then () 
     else (admit();tl_lt (L.hd (v_of (inverse_st s2'))) (v_of s2') (fst last2)))

let linearizable_s1_0''_base_ind (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    ops_of s1 = ops_of lca /\ ops_of s2' = ops_of lca /\
                    length (ops_of lca) > 0 /\

                    (let l' = inverse_st lca in
                    let s1' = inverse_st s1 in
                    let s2'' = inverse_st s2' in
                    do_pre (v_of s2'') last2 /\ 
                    consistent_branches l' s1' (do_st s2'' last2) /\
                    ops_of s1' = ops_of l' /\ ops_of s2'' = ops_of l' /\
                    merge_pre (v_of l') (v_of s1') (do (v_of s2'') last2) /\
                    eq (do (v_of s2'') last2) (concrete_merge (v_of l') (v_of s1') (do (v_of s2'') last2))) /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2))

          (ensures eq (do (v_of s2') last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2))) =
  lem_equal (do (v_of s2') last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) //done

let linearizable_s1_0''_do_pre (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    is_prefix (ops_of lca) (ops_of s2') /\
                    ops_of s1 = ops_of lca /\                    
                    fst last2 > 0 /\
                    length (ops_of s2') > length (ops_of lca))
         
          (ensures do_pre (v_of (inverse_st s2')) last2) = admit()

let linearizable_s1_0''_merge_pre (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    ops_of s1 = ops_of lca /\
                    length (ops_of s2') > length (ops_of lca) /\

                    (let inv2 = inverse_st s2' in
                    do_pre (v_of inv2) last2 /\
                    consistent_branches lca s1 (do_st inv2 last2) /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2)))
         
          (ensures merge_pre (v_of lca) (v_of s1) (do (v_of (inverse_st s2')) last2)) = admit()

let linearizable_s1_0''_ind (lca s1 s2':st) (last2:op_t)
  : Lemma (requires do_pre (v_of s2') last2 /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    ops_of s1 = ops_of lca /\
                    length (ops_of s2') > length (ops_of lca) /\

                    (let inv2 = inverse_st s2' in
                    do_pre (v_of inv2) last2 /\
                    consistent_branches lca s1 (do_st inv2 last2) /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of inv2) last2) /\
                    eq (do (v_of inv2) last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of inv2) last2))) /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2))
        
          (ensures eq (do (v_of s2') last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2))) =
  lem_equal (do (v_of s2') last2) (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) //done

let linearizable_s1_0_s2_0_base (lca s1 s2:st)
  : Lemma (requires consistent_branches lca s1 s2 /\
                    ops_of s1 == ops_of lca /\ ops_of s2 == ops_of lca /\
                    merge_pre (v_of lca) (v_of s1) (v_of s2))
        
          (ensures eq (v_of lca) (concrete_merge (v_of lca) (v_of s1) (v_of s2))) = admit()

let linearizable_gt0_base_fts (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2) /\
                    First_then_second? (resolve_conflict last1 last2))
         
          (ensures merge_pre (v_of lca) (v_of s1) (do (v_of s2) last2) /\
                   do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1 /\
                   eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = 
  lem_equal (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
            (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))

let linearizable_gt0_base_stf (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2) /\
                    Second_then_first? (resolve_conflict last1 last2))
          (ensures merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2) /\
                   do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2 /\
                   eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) =
  lem_equal (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
            (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))

let linearizable_gt0_base (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    ops_of s1 = ops_of lca /\ ops_of s2 = ops_of lca /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))
         
          (ensures (First_then_second? (resolve_conflict last1 last2) ==>
                      merge_pre (v_of lca) (v_of s1) (do (v_of s2) last2) /\
                      do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1 /\
                      (eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                          (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))) /\

                   (Second_then_first? (resolve_conflict last1 last2) ==>
                      merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2) /\
                      do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2 /\
                      (eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                          (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))))) = 
  if First_then_second? (resolve_conflict last1 last2) then
    linearizable_gt0_base_fts lca s1 s2 last1 last2
  else linearizable_gt0_base_stf lca s1 s2 last1 last2

let linearizable_gt0_s2'_do_pre (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca (do_st s1 last1) s2 /\
                    consistent_branches lca s1 s2 /\
                    fst last1 <> fst last2 /\
                    Second_then_first? (resolve_conflict last1 last2)) 
         
          (ensures (length (ops_of s2) > length (ops_of lca) ==> do_pre (v_of (inverse_st s2)) last2) /\
                   (length (ops_of s1) > length (ops_of lca) ==> do_pre (v_of (inverse_st s1)) last1)) = ()

let linearizable_gt0_s2'_merge_pre (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca (do_st s1 last1) s2 /\
                    consistent_branches lca s1 s2 /\
                    fst last1 <> fst last2 /\
                    Second_then_first? (resolve_conflict last1 last2) /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)) 
         
          (ensures (length (ops_of s1) > length (ops_of lca) /\ do_pre (v_of (inverse_st s1)) last1 ==>
                      merge_pre (v_of lca) (do (v_of (inverse_st s1)) last1) (do (v_of s2) last2)) /\
                   (length (ops_of s2) > length (ops_of lca) /\ do_pre (v_of (inverse_st s2)) last2 ==>
                      merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of (inverse_st s2)) last2))) = ()

let linearizable_gt0_s1'_do_pre (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    fst last1 <> fst last2 /\
                    First_then_second? (resolve_conflict last1 last2)) 
          (ensures (length (ops_of s2) > length (ops_of lca) ==> do_pre (v_of (inverse_st s2)) last2) /\
                   (length (ops_of s1) > length (ops_of lca) ==> do_pre (v_of (inverse_st s1)) last1)) = ()

let linearizable_gt0_s1'_merge_pre (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    fst last1 <> fst last2 /\
                    First_then_second? (resolve_conflict last1 last2) /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))
          (ensures (length (ops_of s1) > length (ops_of lca) /\ do_pre (v_of (inverse_st s1)) last1 ==>
                      merge_pre (v_of lca) (do (v_of (inverse_st s1)) last1) (do (v_of s2) last2)) /\
                   (length (ops_of s2) > length (ops_of lca) /\ do_pre (v_of (inverse_st s2)) last2 ==>
                      merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of (inverse_st s2)) last2))) = ()

let linearizable_gt0_ind_fts (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    length (ops_of s2) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2) /\
                    (let s2' = inverse_st s2 in
                    do_pre (v_of s2') last2 /\
                    First_then_second? (resolve_conflict last1 last2) /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    consistent_branches lca (do_st s1 last1) (do_st s2' last2) /\
                    consistent_branches lca s1 (do_st s2 last2) /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2) /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2) /\
                    do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) last1 /\
                    eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2)))) 
          (ensures merge_pre (v_of lca) (v_of s1) (do (v_of s2) last2) /\
                   do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1 /\
                   eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) = 
  lem_equal (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
            (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))
                    
let linearizable_gt0_ind_stf (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    length (ops_of s2) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2) /\
                    (let s2' = inverse_st s2 in
                    do_pre (v_of s2') last2 /\
                    ops_of s1 = ops_of lca /\
                    Second_then_first? (resolve_conflict last1 last2) /\
                    consistent_branches lca (do_st s1 last1) s2' /\
                    consistent_branches lca (do_st s1 last1) (do_st s2' last2) /\
                    consistent_branches lca (do_st s1 last1) s2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2') /\
                    do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')) last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2) /\
                    eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2))))
          (ensures merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2) /\
                   do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2 /\
                   eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) =
  lem_equal (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
            (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))

let linearizable_gt0_ind1_fts (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    length (ops_of s1) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2) /\
                    (let s1' = inverse_st s1 in
                    do_pre (v_of s1') last1 /\
                    ops_of s2 = ops_of lca /\
                    First_then_second? (resolve_conflict last1 last2) /\
                    consistent_branches lca s1' (do_st s2 last2) /\
                    consistent_branches lca (do_st s1' last1) (do_st s2 last2) /\
                    consistent_branches lca s1 (do_st s2 last2) /\
                    merge_pre (v_of lca) (v_of s1') (do (v_of s2) last2) /\
                    merge_pre (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2) /\
                    do_pre (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2)) last1 /\
                    eq (do (concrete_merge (v_of lca) (v_of s1') (do (v_of s2) last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2)))) 
          (ensures merge_pre (v_of lca) (v_of s1) (do (v_of s2) last2) /\
                   do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1 /\
                   eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) =
  lem_equal (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
            (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))

let linearizable_gt0_ind1_stf (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    length (ops_of s1) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2) /\
                    Second_then_first? (resolve_conflict last1 last2) /\
                    (let s1' = inverse_st s1 in
                    do_pre (v_of s1') last1 /\
                    consistent_branches lca (do_st s1' last1) s2 /\
                    consistent_branches lca (do_st s1' last1) (do_st s2 last2) /\
                    consistent_branches lca (do_st s1 last1) s2 /\
                    merge_pre (v_of lca) (do (v_of s1') last1) (v_of s2) /\
                    merge_pre (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2) /\
                    do_pre (concrete_merge (v_of lca) (do (v_of s1') last1) (v_of s2)) last2 /\
                    eq (do (concrete_merge (v_of lca) (do (v_of s1') last1) (v_of s2)) last2)
                       (concrete_merge (v_of lca) (do (v_of s1') last1) (do (v_of s2) last2))))
          (ensures merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2) /\
                   do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2 /\    
                   eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                      (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))) =
  lem_equal (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
            (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))

let fts_merge_pre1 (lca s1 s2:st)
  : Lemma (requires consistent_branches lca s1 s2 /\
                    merge_pre (v_of lca) (v_of s1) (v_of s2) /\
                    length (ops_of s1) > length (ops_of lca) /\
                    length (ops_of s2) > length (ops_of lca) /\
                    (let _, last1 = un_snoc (ops_of s1) in 
                     let _, last2 = un_snoc (ops_of s2) in 
                     fst last1 <> fst last2 /\
                     First_then_second? (resolve_conflict last1 last2)))
          (ensures merge_pre (v_of lca) (v_of (inverse_st s1)) (v_of s2)) = ()
   
let stf_merge_pre1 (lca s1 s2:st)
  : Lemma (requires consistent_branches lca s1 s2 /\
                    merge_pre (v_of lca) (v_of s1) (v_of s2) /\
                    length (ops_of s1) > length (ops_of lca) /\
                    length (ops_of s2) > length (ops_of lca) /\
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     Second_then_first? (resolve_conflict last1 last2)))
          (ensures merge_pre (v_of lca) (v_of s1) (v_of (inverse_st s2))) = ()

(*let convergence1 (lca s1' s2:concrete_st) (ls1' ls2:log) (o:op_t)
  : Lemma (requires do_pre s1' o /\
                    merge_pre lca (do s1' o) s2 /\
                    merge_pre lca s1' s2 /\
                    merge_pre s1' (do s1' o) (concrete_merge lca s1' s2))                   
          (ensures eq (concrete_merge lca (do s1' o) s2)
                      (concrete_merge s1' (do s1' o) (concrete_merge lca s1' s2))) =
  lem_equal (concrete_merge lca (do s1' o) s2)
            (concrete_merge s1' (do s1' o) (concrete_merge lca s1' s2))

let convergence2 (lca' lca s3 s1 s2:concrete_st) (llca ls3 ls1 ls2:log)
  : Lemma (requires merge_pre lca s3 s1 /\
                    merge_pre lca' (concrete_merge lca s3 s1) s2 /\
                    merge_pre lca' s1 s2 /\
                    merge_pre s1 (concrete_merge lca s3 s1) (concrete_merge lca' s1 s2))
          (ensures eq (concrete_merge lca' (concrete_merge lca s3 s1) s2)
                      (concrete_merge s1 (concrete_merge lca s3 s1) (concrete_merge lca' s1 s2))) = 
  lem_equal (concrete_merge lca' (concrete_merge lca s3 s1) s2)
            (concrete_merge s1 (concrete_merge lca s3 s1) (concrete_merge lca' s1 s2))

let convergence3 (s:concrete_st) (op:op_t)
  : Lemma (requires do_pre s op /\
                    merge_pre s s (do s op))
          (ensures eq (concrete_merge s s (do s op)) (do s op)) =
  lem_equal (concrete_merge s s (do s op)) (do s op)




let linearizable_gt0_ind (lca s1 s2:st) (last1 last2:op_t)
  : Lemma (requires do_pre (v_of s1) last1 /\ do_pre (v_of s2) last2 /\ 
                    consistent_branches lca (do_st s1 last1) (do_st s2 last2) /\
                    consistent_branches lca s1 s2 /\
                    length (ops_of s2) > length (ops_of lca) /\
                    fst last1 <> fst last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2))
       
          (ensures (let s2' = inverse_st s2 in
                   do_pre (v_of s2') last2 /\
                   ((First_then_second? (resolve_conflict last1 last2) /\
                    consistent_branches lca s1 (do_st s2' last2) /\
                    consistent_branches lca (do_st s1 last1) (do_st s2' last2) /\
                    consistent_branches lca s1 (do_st s2 last2) /\
                    merge_pre (v_of lca) (v_of s1) (do (v_of s2') last2) /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2) /\
                    do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) last1 /\
                    eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') last2)) last1)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2))) ==>
                   
                    (merge_pre (v_of lca) (v_of s1) (do (v_of s2) last2) /\
                     do_pre (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1 /\
                     eq (do (concrete_merge (v_of lca) (v_of s1) (do (v_of s2) last2)) last1)
                        (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))) /\
                          
                   ((ops_of s1 = ops_of lca /\
                    Second_then_first? (resolve_conflict last1 last2) /\
                    consistent_branches lca (do_st s1 last1) s2' /\
                    consistent_branches lca (do_st s1 last1) (do_st s2' last2) /\
                    consistent_branches lca (do_st s1 last1) s2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2') /\
                    do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')) last2 /\
                    merge_pre (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2) /\
                    eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2')) last2)
                       (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2') last2))) ==>
                   
                    (merge_pre (v_of lca) (do (v_of s1) last1) (v_of s2) /\
                     do_pre (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2 /\
                     eq (do (concrete_merge (v_of lca) (do (v_of s1) last1) (v_of s2)) last2)
                        (concrete_merge (v_of lca) (do (v_of s1) last1) (do (v_of s2) last2)))))) =
  if First_then_second? (resolve_conflict last1 last2) then
    linearizable_gt0_ind_fts lca s1 s2 last1 last2
  else linearizable_gt0_ind_stf lca s1 s2 last1 last2


////////////////////////////////////////////////////////////////
//// Sequential implementation //////

// the concrete state 
type concrete_st_s = seq string

// init state 
let init_st_s = empty

// apply an operation to a state 
let do_s (s:concrete_st_s) (op:op_t) : concrete_st_s = cons (snd op) s

//equivalence relation between the concrete states of sequential type and MRDT
let eq_sm (st_s:concrete_st_s) (st:concrete_st) =
  length st_s = length st /\
  (forall (i:nat). i < length st_s ==> index st_s i == snd (index st i))

//initial states are equivalent
let initial_eq _
  : Lemma (ensures eq_sm init_st_s init_st) = ()

//equivalence between states of sequential type and MRDT at every operation
let do_eq (st_s:concrete_st_s) (st:concrete_st) (op:op_t)
  : Lemma (requires eq_sm st_s st)
          (ensures eq_sm (do_s st_s op) (do st op)) = ()
  
////////////////////////////////////////////////////////////////
*)
