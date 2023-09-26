module Framework_comm

open FStar.Seq
open App_comm
open SeqUtils

#set-options "--query_stats"

// l is interleaving of l1 and l2
let rec is_interleaving (l l1 l2:log)
  : Tot eqtype (decreases %[Seq.length l1; Seq.length l2]) =

  // if l1 is empty, then l == l2
  (Seq.length l1 == 0 ==> l == l2)

  /\

  // similarly for l2 being empty
  ((Seq.length l1 > 0  /\ Seq.length l2 == 0) ==> l == l1)

  /\

  // if both are non-empty

  ((Seq.length l1 > 0 /\ Seq.length l2 > 0 /\
    exists_triple (snd (un_snoc l1)) l2) ==>
    (let pre, op, suf = find_triple (snd (un_snoc l1)) l2 in
      (exists l'.
         is_interleaving l' l1 (pre ++ suf) /\
         l == Seq.snoc l' op)))

   /\

   ((Seq.length l1 > 0 /\ Seq.length l2 > 0 /\
    not (exists_triple (snd (un_snoc l1)) l2) /\
    exists_triple (snd (un_snoc l2)) l1) ==>
    (let pre, op, suf = find_triple (snd (un_snoc l2)) l1 in
      (exists l'.
         is_interleaving l' (pre ++ suf) l2 /\
         l == Seq.snoc l' op)))

   /\

   ((Seq.length l1 > 0 /\ Seq.length l2 > 0 /\
    not (exists_triple (snd (un_snoc l1)) l2) /\
    not (exists_triple (snd (un_snoc l2)) l1)) ==>

    (let prefix1, last1 = un_snoc l1 in
     let prefix2, last2 = un_snoc l2 in

    (exists l'.
       is_interleaving l' prefix1 prefix2 /\
       l == Seq.snoc l' last1)

    \/

    (exists l'.
       is_interleaving l' prefix1 prefix2 /\
       l == Seq.snoc l' last2)

    \/
    
    (exists l'.
        is_interleaving l' l1 prefix2 /\
        l == Seq.snoc l' last2)    
     
    \/

    (exists l'.
        is_interleaving l' prefix1 l2 /\
        l == Seq.snoc l' last1)))

// l is an interleaving of s1 - lca and s2 - lca
let interleaving_predicate (l:log) (lca s1:st)
  (s2:st{is_prefix (ops_of lca) (ops_of s1) /\
         is_prefix (ops_of lca) (ops_of s2)}) =
  split_prefix init_st (ops_of lca) (ops_of s1);
  split_prefix init_st (ops_of lca) (ops_of s2);
  is_interleaving l (diff (ops_of s1) (ops_of lca)) (diff (ops_of s2) (ops_of lca)) /\
  eq (apply_log (v_of lca) l)
     (concrete_merge (v_of lca) (v_of s1) (v_of s2))

let linearizable_s1_01 (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    ops_of s1 == ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1))
          (ensures (exists l. interleaving_predicate l lca s1 s2)) =
  split_prefix init_st (ops_of lca) (ops_of s2);
  linearizable_s1_0 lca s1 s2

let linearizable_s2_01 (lca s1 s2:st)
  : Lemma (requires is_prefix (ops_of lca) (ops_of s1) /\
                    is_prefix (ops_of lca) (ops_of s2) /\
                    Seq.length (ops_of s1) > Seq.length (ops_of lca) /\
                    ops_of s2 == ops_of lca /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1))
          (ensures (exists l. interleaving_predicate l lca s1 s2)) =
  split_prefix init_st (ops_of lca) (ops_of s1);
  linearizable_s1_0 lca s2 s1;
  merge_is_comm lca s1 s2;
  symmetric (concrete_merge (v_of lca) (v_of s1) (v_of s2)) (concrete_merge (v_of lca) (v_of s2) (v_of s1));
  transitive (v_of s1) (concrete_merge (v_of lca) (v_of s2) (v_of s1)) (concrete_merge (v_of lca) (v_of s1) (v_of s2))

let interleaving_helper_inv2_comm (lca s1 s2 l':log)
  : Lemma
      (requires (*Seq.length s1 > 0 /\*) is_prefix lca s1 /\ is_prefix lca s2 /\
                Seq.length (diff s1 lca) > 0 /\ Seq.length (diff s2 lca) > 0 /\
                exists_triple (snd (un_snoc s1)) (diff s2 lca) /\
                (let (pre2, op2, suf2) = find_triple (snd (un_snoc s1)) (diff s2 lca) in
                is_interleaving l' (diff s1 lca) (pre2 ++ suf2)))
      (ensures (let (_, op2, _) = find_triple (snd (un_snoc s1)) (diff s2 lca) in
                is_interleaving (Seq.snoc l' op2) (diff s1 lca) (diff s2 lca)))
  = let (_, op2, _) = find_triple (snd (un_snoc (diff s1 lca))) (diff s2 lca) in
    let l = Seq.snoc l' op2 in
    ()

#push-options "--z3rlimit 50"
let interleaving_helper_inv1_comm (lca s1 s2 l':log)
  : Lemma
      (requires (*Seq.length s2 > 0 /\*) is_prefix lca s1 /\ is_prefix lca s2 /\
                Seq.length (diff s1 lca) > 0 /\ Seq.length (diff s2 lca) > 0 /\
                not (exists_triple (snd (un_snoc s1)) (diff s2 lca)) /\
                exists_triple (snd (un_snoc s2)) (diff s1 lca) /\
                (let (pre1, op1, suf1) = find_triple (snd (un_snoc s2)) (diff s1 lca) in
                is_interleaving l' (pre1 ++ suf1) (diff s2 lca)))
      (ensures (let (_, op1, _) = find_triple (snd (un_snoc s2)) (diff s1 lca) in
                is_interleaving (Seq.snoc l' op1) (diff s1 lca) (diff s2 lca)))
  = let (_, op1, _) = find_triple (snd (un_snoc (diff s2 lca))) (diff s1 lca) in
    let l = Seq.snoc l' op1 in
    ()

let interleaving_helper_inv1 (lca s1 s2 l':log)
  : Lemma
      (requires Seq.length s1 > 0 /\ is_prefix lca s1 /\ is_prefix lca s2 /\
                Seq.length (diff s1 lca) > 0 /\ Seq.length (diff s2 lca) > 0 /\
                not (exists_triple (snd (un_snoc s1)) (diff s2 lca)) /\
                not (exists_triple (snd (un_snoc s2)) (diff s1 lca)) /\
                is_interleaving l' (diff (fst (Seq.un_snoc s1)) lca) (diff s2 lca))
      (ensures (let _, last1 = un_snoc s1 in
                is_interleaving (Seq.snoc l' last1) (diff s1 lca) (diff s2 lca)))
  = let prefix1, last1 = Seq.un_snoc (diff s1 lca) in
    let l = Seq.snoc l' last1 in
    introduce exists l'. is_interleaving l' prefix1 (diff s2 lca) /\
                    l = Seq.snoc l' last1
    with l'
    and ()
    
let interleaving_helper_inv2 (lca s1 s2 l':log)
  : Lemma
      (requires Seq.length s2 > 0 /\ is_prefix lca s1 /\ is_prefix lca s2 /\
                Seq.length (diff s1 lca) > 0 /\ Seq.length (diff s2 lca) > 0 /\
                not (exists_triple (snd (un_snoc s1)) (diff s2 lca)) /\
                not (exists_triple (snd (un_snoc s2)) (diff s1 lca)) /\
                is_interleaving l' (diff s1 lca) (diff (fst (Seq.un_snoc s2)) lca))
      (ensures (let _, last2 = un_snoc s2 in
                is_interleaving (Seq.snoc l' last2) (diff s1 lca) (diff s2 lca)))
  = let prefix2, last2 = Seq.un_snoc (diff s2 lca) in
    let l = Seq.snoc l' last2 in
    introduce exists l'. is_interleaving l' (diff s1 lca) prefix2 /\
                    l = Seq.snoc l' last2
    with l'
    and ()

let interleaving_helper_inv1inv2 (lca s1 s2 l':log)
  : Lemma
      (requires Seq.length s2 > 0 /\ Seq.length s1 > 0 /\ 
                is_prefix lca s1 /\ is_prefix lca s2 /\
                Seq.length (diff s1 lca) > 0 /\ Seq.length (diff s2 lca) > 0 /\
                not (exists_triple (snd (un_snoc s1)) (diff s2 lca)) /\
                not (exists_triple (snd (un_snoc s2)) (diff s1 lca)) /\
                is_interleaving l' (diff (fst (Seq.un_snoc s1)) lca) (diff (fst (Seq.un_snoc s2)) lca))
      (ensures (let _, last1 = un_snoc s1 in
                is_interleaving (Seq.snoc l' last1) (diff s1 lca) (diff s2 lca)))
  = let prefix1, last1 = Seq.un_snoc (diff s1 lca) in
    let prefix2, _ = Seq.un_snoc (diff s2 lca) in
    let l = Seq.snoc l' last1 in
    introduce exists l'. is_interleaving l' prefix1 prefix2 /\
                    l = Seq.snoc l' last1
    with l'
    and ()

let ls1s2_to_ls1''s2 (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last2 = un_snoc (ops_of s2) in
                     exists_triple last2 (diff (ops_of s1) (ops_of lca))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let (_, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                    suf1 == snd (pre_suf (ops_of s1) op1) /\
                    (let s1' = inverse_st_op s1 op1 in
                    consistent_branches lca s1' s2))) = admit()

let ls1s2_to_ls1''s2op (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last2 = un_snoc (ops_of s2) in
                     exists_triple last2 (diff (ops_of s1) (ops_of lca))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let (_, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                    suf1 == snd (pre_suf (ops_of s1) op1) /\
                    (let s1' = inverse_st_op s1 op1 in
                    consistent_branches lca (do_st s1' op1) s2))) = admit()
                    
// taking inverse on any one branch and applying the operation again is equivalent to
// concrete merge
let linearizable_gt0 (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\ 
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     
                     (exists_triple last1 (diff (ops_of s2) (ops_of lca)) ==>
                       (let (_, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
                        suf2 == snd (pre_suf (ops_of s2) op2))) /\

                      ((not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                        exists_triple last2 (diff (ops_of s1) (ops_of lca))) ==>
                          (let (_, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                           suf1 == snd (pre_suf (ops_of s1) op1))) /\

                     ((not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                       not (exists_triple last2 (diff (ops_of s1) (ops_of lca)))) ==>
                         fst last1 <> fst last2 /\
                         (First_then_second? (resolve_conflict last1 last2) ==>
                          is_prefix (ops_of lca) (ops_of (inverse_st s1))) /\
                           
                         (Second_then_first? (resolve_conflict last1 last2) ==>
                          is_prefix (ops_of lca) (ops_of (inverse_st s2))))))
        
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    let _, last2 = un_snoc (ops_of s2) in
                    
                    (exists_triple last1 (diff (ops_of s2) (ops_of lca)) ==>
                       (let (pre2, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
                       (let s2' = inverse_st_op s2 op2 in
                       eq (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) op2)
                          (concrete_merge (v_of lca) (v_of s1) (do (v_of s2') op2))))) /\

                    ((not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     exists_triple last2 (diff (ops_of s1) (ops_of lca))) ==>
                       (let (pre1, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                       (let s1' = inverse_st_op s1 op1 in                    
                       eq (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) op1)
                          (concrete_merge (v_of lca) (do (v_of s1') op1) (v_of s2))))) /\

                    ((not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                      not (exists_triple last2 (diff (ops_of s1) (ops_of lca)))) ==>
                    
                    (First_then_second? (resolve_conflict last1 last2) ==>                    
                      eq (do (concrete_merge (v_of lca) (v_of (inverse_st s1)) (v_of s2)) last1)
                         (concrete_merge (v_of lca) (v_of s1) (v_of s2))) /\                                                    
                    (Second_then_first? (resolve_conflict last1 last2) ==>                   
                      eq (do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) last2)
                         (concrete_merge (v_of lca) (v_of s1) (v_of s2)))))) =
                         
  let _, last1 = un_snoc (ops_of s1) in
  let _, last2 = un_snoc (ops_of s2) in
  if exists_triple last1 (diff (ops_of s2) (ops_of lca)) then
     (ls1s2_to_ls1''s2 lca s2 s1;
      ls1s2_to_ls1''s2op lca s2 s1;
      linearizable_gt0_s2'_op lca s1 s2)
  else if not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) &&
          exists_triple last2 (diff (ops_of s1) (ops_of lca)) then
     (ls1s2_to_ls1''s2 lca s1 s2;
      ls1s2_to_ls1''s2op lca s1 s2;
      linearizable_gt0_s1'_op lca s1 s2)
  else 
    (if First_then_second? (resolve_conflict last1 last2) then
       (ls1s2_to_ls1's2 lca s1 s2;
        linearizable_gt0_s1' lca s1 s2)
     else if Second_then_first? (resolve_conflict last1 last2) then
       (ls1s2_to_ls1's2 lca s2 s1;
        linearizable_gt0_s2' lca s1 s2)
     else ())

let interleaving_s1_inv (lca s1 s2:st) (l':log)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\ 
                    not (exists_triple (snd (un_snoc (ops_of s1))) (diff (ops_of s2) (ops_of lca))) /\
                    not (exists_triple (snd (un_snoc (ops_of s2))) (diff (ops_of s1) (ops_of lca))) /\
                    is_prefix (ops_of lca) (ops_of (inverse_st s1)) /\
                    interleaving_predicate l' lca (inverse_st s1) s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     First_then_second? (resolve_conflict last1 last2)))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    let l = Seq.snoc l' last1 in
                    interleaving_predicate l lca s1 s2 /\
                    (exists l. interleaving_predicate l lca s1 s2))) =

  let _, last1 = un_snoc (ops_of s1) in
  let l = Seq.snoc l' last1 in
  interleaving_helper_inv1 (ops_of lca) (ops_of s1) (ops_of s2) l';
  linearizable_gt0 lca s1 s2;
  let s1' = inverse_st s1 in
  symmetric (apply_log (v_of lca) l') (concrete_merge (v_of lca) (v_of s1') (v_of s2));
  lem_do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) (apply_log (v_of lca) l') last1; 
  symmetric (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last1)
            (do (apply_log (v_of lca) l') last1);
  inverse_helper (v_of lca) l' last1;
  eq_is_equiv (apply_log (v_of lca) l) (do (apply_log (v_of lca) l') last1);
  transitive (apply_log (v_of lca) l)
             (do (apply_log (v_of lca) l') last1)
             (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last1); 
  transitive (apply_log (v_of lca) l) (do (concrete_merge (v_of lca) (v_of s1') (v_of s2)) last1)
             (concrete_merge (v_of lca) (v_of s1) (v_of s2));
  assert (interleaving_predicate l lca s1 s2); ()

let interleaving_s2_inv (lca s1 s2:st) (l':log)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    is_prefix (ops_of lca) (ops_of (inverse_st s2)) /\
                    not (exists_triple (snd (un_snoc (ops_of s1))) (diff (ops_of s2) (ops_of lca))) /\
                    not (exists_triple (snd (un_snoc (ops_of s2))) (diff (ops_of s1) (ops_of lca))) /\
                    interleaving_predicate l' lca s1 (inverse_st s2) /\
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     Second_then_first? (resolve_conflict last1 last2)))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let l = Seq.snoc l' last2 in
                    interleaving_predicate l lca s1 s2 /\
                    (exists l. interleaving_predicate l lca s1 s2))) =
  let _, last2 = un_snoc (ops_of s2) in
  let l = Seq.snoc l' last2 in
  interleaving_helper_inv2 (ops_of lca) (ops_of s1) (ops_of s2) l'; 
  linearizable_gt0 lca s1 s2;
  let s2' = inverse_st s2 in
  symmetric (apply_log (v_of lca) l') (concrete_merge (v_of lca) (v_of s1) (v_of s2'));
  lem_do (concrete_merge (v_of lca) (v_of s1) (v_of (inverse_st s2))) (apply_log (v_of lca) l') last2;
  symmetric (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
            (do (apply_log (v_of lca) l') last2);
  inverse_helper (v_of lca) l' last2;
  eq_is_equiv (apply_log (v_of lca) l) (do (apply_log (v_of lca) l') last2);
  transitive (apply_log (v_of lca) l)
             (do (apply_log (v_of lca) l') last2)
             (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2); 
  transitive (apply_log (v_of lca) l) (do (concrete_merge (v_of lca) (v_of s1) (v_of s2')) last2)
             (concrete_merge (v_of lca) (v_of s1) (v_of s2));
  assert (interleaving_predicate l lca s1 s2); ()

let rec lem_app (l a b:log)
  : Lemma (requires l ++ a == l ++ b)
          (ensures a == b) (decreases length l) =
  match length l with
  |0 -> lemma_empty l; append_empty_l a; append_empty_l b
  |_ -> lemma_append_cons l a; 
       lemma_append_cons l b;
       lemma_cons_inj (head l) (head l) (tail l ++ a) (tail l ++ b);
       lem_app (tail l) a b

#push-options "--z3rlimit 50"
let interleaving_s2_inv_comm (lca s1 s2:st) (l':log)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     fst last1 <> fst last2 /\
                     exists_triple last1 (diff (ops_of s2) (ops_of lca)) /\
                    (let (pre2, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
                     lem_suf_equal (ops_of lca) (ops_of s2) op2;
                  
                    (let inv2 = inverse_st_op s2 op2 in
                    is_prefix (ops_of lca) (ops_of inv2) /\
                    interleaving_predicate l' lca s1 inv2))))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                    let (_, op2, _) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in
                    let l = Seq.snoc l' op2 in
                    interleaving_predicate l lca s1 s2 /\
                    (exists l. interleaving_predicate l lca s1 s2))) = 
  let _, last1 = un_snoc (ops_of s1) in
  let (pre2, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in 
  lem_suf_equal (ops_of lca) (ops_of s2) op2;
  lem_inverse_op (ops_of lca) (ops_of s2) op2; 
  let inv2 = inverse_st_op s2 op2 in
  lem_diff (ops_of inv2) (ops_of lca);
  lem_app (ops_of lca) (pre2 ++ suf2) (diff (ops_of inv2) (ops_of lca));
  let l = Seq.snoc l' op2 in 
  lem_diff (ops_of s1) (ops_of lca); 
  lem_diff (ops_of s2) (ops_of lca);
  interleaving_helper_inv2_comm (ops_of lca) (ops_of s1) (ops_of s2) l';
  assert (is_interleaving l (diff (ops_of s1) (ops_of lca)) (diff (ops_of s2) (ops_of lca)));
  linearizable_gt0 lca s1 s2;
  symmetric (v_of s2) (do (v_of inv2) op2);
  lem_trans_merge_s2' (v_of lca) (v_of s1) (do (v_of inv2) op2) (v_of s2); 
  transitive (do (concrete_merge (v_of lca) (v_of s1) (v_of inv2)) op2)
             (concrete_merge (v_of lca) (v_of s1) (do (v_of inv2) op2))
             (concrete_merge (v_of lca) (v_of s1) (v_of s2));
  symmetric (apply_log (v_of lca) l') (concrete_merge (v_of lca) (v_of s1) (v_of inv2));
  lem_do (concrete_merge (v_of lca) (v_of s1) (v_of inv2)) (apply_log (v_of lca) l') op2;
  symmetric (do (concrete_merge (v_of lca) (v_of s1) (v_of inv2)) op2)
            (do (apply_log (v_of lca) l') op2);
  inverse_helper (v_of lca) l' op2;
  eq_is_equiv (apply_log (v_of lca) l) (do (apply_log (v_of lca) l') op2);
  transitive (apply_log (v_of lca) l)
             (do (apply_log (v_of lca) l') op2)
             (do (concrete_merge (v_of lca) (v_of s1) (v_of inv2)) op2); 
  transitive (apply_log (v_of lca) l) (do (concrete_merge (v_of lca) (v_of s1) (v_of inv2)) op2)
             (concrete_merge (v_of lca) (v_of s1) (v_of s2));
  assert (interleaving_predicate l lca s1 s2); ()           

let interleaving_s1_inv_comm (lca s1 s2:st) (l':log)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                    let _, last2 = un_snoc (ops_of s2) in
                    fst last1 <> fst last2 /\
                    not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                    exists_triple last2 (diff (ops_of s1) (ops_of lca)) /\
                    (let (pre1, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                    lem_suf_equal (ops_of lca) (ops_of s1) op1;
                    
                    (let inv1 = inverse_st_op s1 op1 in
                    is_prefix (ops_of lca) (ops_of inv1) /\
                    interleaving_predicate l' lca inv1 s2))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let (_, op1, _) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in
                    let l = Seq.snoc l' op1 in
                    interleaving_predicate l lca s1 s2 /\
                    (exists l. interleaving_predicate l lca s1 s2))) =
  let _, last2 = un_snoc (ops_of s2) in
  let (pre1, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in 
  lem_suf_equal (ops_of lca) (ops_of s1) op1;
  lem_inverse_op (ops_of lca) (ops_of s1) op1; 
  let inv1 = inverse_st_op s1 op1 in
  lem_diff (ops_of inv1) (ops_of lca);
  lem_app (ops_of lca) (pre1 ++ suf1) (diff (ops_of inv1) (ops_of lca));
  let l = Seq.snoc l' op1 in 
  lem_diff (ops_of s1) (ops_of lca); 
  lem_diff (ops_of s2) (ops_of lca);
  interleaving_helper_inv1_comm (ops_of lca) (ops_of s1) (ops_of s2) l';
  assert (is_interleaving l (diff (ops_of s1) (ops_of lca)) (diff (ops_of s2) (ops_of lca)));
  linearizable_gt0 lca s1 s2;
  symmetric (v_of s1) (do (v_of inv1) op1);
  assert (eq (do (concrete_merge (v_of lca) (v_of inv1) (v_of s2)) op1)
             (concrete_merge (v_of lca) (do (v_of inv1) op1) (v_of s2)));
  lem_trans_merge_s1' (v_of lca) (do (v_of inv1) op1) (v_of s2) (v_of s1);  
  transitive (do (concrete_merge (v_of lca) (v_of inv1) (v_of s2)) op1)
             (concrete_merge (v_of lca) (do (v_of inv1) op1) (v_of s2))
             (concrete_merge (v_of lca) (v_of s1) (v_of s2));
  symmetric (apply_log (v_of lca) l') (concrete_merge (v_of lca) (v_of inv1) (v_of s2));
  lem_do (concrete_merge (v_of lca) (v_of inv1) (v_of s2)) (apply_log (v_of lca) l') op1;
  symmetric (do (concrete_merge (v_of lca) (v_of inv1) (v_of s2)) op1)
            (do (apply_log (v_of lca) l') op1);
  inverse_helper (v_of lca) l' op1; 
  eq_is_equiv (apply_log (v_of lca) l) (do (apply_log (v_of lca) l') op1);
  transitive (apply_log (v_of lca) l)
             (do (apply_log (v_of lca) l') op1)
             (do (concrete_merge (v_of lca) (v_of inv1) (v_of s2)) op1); 
  transitive (apply_log (v_of lca) l) (do (concrete_merge (v_of lca) (v_of inv1) (v_of s2)) op1)
             (concrete_merge (v_of lca) (v_of s1) (v_of s2));
  assert (interleaving_predicate l lca s1 s2); () 

let linearizable_s2_gt0_pre_comm (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1_gt0 lca s1 s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                    exists_triple last1 (diff (ops_of s2) (ops_of lca))))
          (ensures (let _, last1 = un_snoc (ops_of s1) in
                   (let (_, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in 
                    suf2 = snd (pre_suf (ops_of s2) op2) /\
                    (let inv2 = inverse_st_op s2 op2 in 
                    is_prefix (ops_of lca) (ops_of inv2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of inv2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of inv2) (ops_of lca))))))))
  = let _, last1 = un_snoc (ops_of s1) in
    let (pre2, op2, suf2) = find_triple last1 (diff (ops_of s2) (ops_of lca)) in 
    lem_suf_equal (ops_of lca) (ops_of s2) op2;
    let inv2 = inverse_st_op s2 op2 in
    lem_inverse_op (ops_of lca) (ops_of s2) op2;
    assert (is_prefix (ops_of lca) (ops_of inv2)); 
    lem_diff (ops_of inv2) (ops_of lca); 
    append_assoc (ops_of lca) pre2 suf2;
    lem_is_diff (ops_of inv2) (ops_of lca) (pre2 ++ suf2);
    assert (diff (ops_of inv2) (ops_of lca) == pre2 ++ suf2);
    inverse_diff_id_inv2' (ops_of lca) (ops_of s1) (ops_of s2);
    lemma_append_count_assoc_fst pre2 suf2;
    assert (forall id. mem_id id (diff (ops_of inv2) (ops_of lca)) ==> mem_id id (diff (ops_of s2) (ops_of lca))); 
    assert ((forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of inv2) (ops_of lca)) ==> lt id id1) /\
            (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of inv2) (ops_of lca)))));
    ()

let linearizable_s1_gt0_pre_comm (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                    let _, last2 = un_snoc (ops_of s2) in
                    not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                    exists_triple last2 (diff (ops_of s1) (ops_of lca))))
          (ensures (let _, last2 = un_snoc (ops_of s2) in
                    let (_, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in 
                    suf1 = snd (pre_suf (ops_of s1) op1) /\
                    (let inv1 = inverse_st_op s1 op1 in 
                    is_prefix (ops_of lca) (ops_of inv1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of inv1) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of inv1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca))))))) 
  = let _, last2 = un_snoc (ops_of s2) in
    let (pre1, op1, suf1) = find_triple last2 (diff (ops_of s1) (ops_of lca)) in 
    lem_suf_equal (ops_of lca) (ops_of s1) op1;
    let inv1 = inverse_st_op s1 op1 in
    lem_inverse_op (ops_of lca) (ops_of s1) op1;
    assert (is_prefix (ops_of lca) (ops_of inv1));
    lem_diff (ops_of inv1) (ops_of lca); 
    append_assoc (ops_of lca) pre1 suf1;
    lem_is_diff (ops_of inv1) (ops_of lca) (pre1 ++ suf1);
    assert (diff (ops_of inv1) (ops_of lca) == pre1 ++ suf1);
    inverse_diff_id_inv1' (ops_of lca) (ops_of s1) (ops_of s2);
    lemma_append_count_assoc_fst pre1 suf1;
    assert (forall id. mem_id id (diff (ops_of inv1) (ops_of lca)) ==> mem_id id (diff (ops_of s1) (ops_of lca)));
    assert ((forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of inv1) (ops_of lca)) ==> lt id id1) /\
            (forall id. mem_id id (diff (ops_of inv1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))));
    ()
#pop-options

let linearizable_s1_gt0_pre (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                     not (exists_triple last2 (diff (ops_of s1) (ops_of lca))) /\
                     fst last1 <> fst last2 /\
                     First_then_second? (resolve_conflict last1 last2)))
          (ensures (let inv1 = inverse_st s1 in 
                    is_prefix (ops_of lca) (ops_of inv1) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of inv1) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of inv1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))) =
  lem_inverse (ops_of lca) (ops_of s1);
  lastop_diff (ops_of lca) (ops_of s1);
  inverse_diff_id_s1' (ops_of lca) (ops_of s1) (ops_of s2)

let linearizable_s2_gt0_pre (lca s1 s2:st)
  : Lemma (requires consistent_branches_s1s2_gt0 lca s1 s2 /\
                    (let _, last1 = un_snoc (ops_of s1) in
                     let _, last2 = un_snoc (ops_of s2) in
                     not (exists_triple (snd (un_snoc (ops_of s1))) (diff (ops_of s2) (ops_of lca))) /\
                     not (exists_triple (snd (un_snoc (ops_of s2))) (diff (ops_of s1) (ops_of lca))) /\
                     fst last1 <> fst last2 /\
                     Second_then_first? (resolve_conflict last1 last2)))
          (ensures (let inv2 = inverse_st s2 in 
                    is_prefix (ops_of lca) (ops_of inv2) /\
                    (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of inv2) (ops_of lca)) ==> lt id id1) /\
                    (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of inv2) (ops_of lca)))))) =
  lem_inverse (ops_of lca) (ops_of s2);
  lastop_diff (ops_of lca) (ops_of s2);
  inverse_diff_id_s2' (ops_of lca) (ops_of s1) (ops_of s2)

#push-options "--z3rlimit 50"
let rec linearizable (lca s1 s2:st)
  : Lemma 
      (requires 
         consistent_branches lca s1 s2)
      (ensures 
         (exists l. interleaving_predicate l lca s1 s2))
      (decreases %[Seq.length (ops_of s2); Seq.length (ops_of s1)])

  = if ops_of s1 = ops_of lca 
    then begin
      linearizable_s1_01 lca s1 s2
    end
    else 
    if ops_of s2 = ops_of lca
    then begin
      linearizable_s2_01 lca s1 s2
    end
    else begin 
        assert (Seq.length (ops_of s1) > Seq.length (ops_of lca)); 
        assert (Seq.length (ops_of s2) > Seq.length (ops_of lca));
        let _, last1 = un_snoc (ops_of s1) in
        let _, last2 = un_snoc (ops_of s2) in
        lastop_neq (ops_of lca) (ops_of s1) (ops_of s2);
        assert (fst last1 <> fst last2);
        let inv1 = inverse_st s1 in 
        let inv2 = inverse_st s2 in 

        if exists_triple last1 (diff (ops_of s2) (ops_of lca)) then
        begin 
          let pre2, op2, suf2 = find_triple (snd (un_snoc (ops_of s1))) (diff (ops_of s2) (ops_of lca)) in
          lem_suf_equal (ops_of lca) (ops_of s2) op2; 
          let s2' = inverse_st_op s2 op2 in 
          assert (length (ops_of s2') = length (ops_of s2) - 1); 
          linearizable_s2_gt0_pre_comm lca s1 s2;
          linearizable lca s1 s2';
          eliminate exists l'. interleaving_predicate l' lca s1 s2'
          returns exists l. interleaving_predicate l lca s1 s2
          with _. begin
            let l = Seq.snoc l' op2 in
            introduce exists l. interleaving_predicate l lca s1 s2
            with l
            and begin 
              interleaving_s2_inv_comm lca s1 s2 l'
            end
          end
         end

        else if not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) &&
                exists_triple last2 (diff (ops_of s1) (ops_of lca)) then
        begin 
          let pre1, op1, suf1 = find_triple (snd (un_snoc (ops_of s2))) (diff (ops_of s1) (ops_of lca)) in
          lem_suf_equal (ops_of lca) (ops_of s1) op1; 
          let s1' = inverse_st_op s1 op1 in 
          assert (length (ops_of s1') = length (ops_of s1) - 1);
          linearizable_s1_gt0_pre_comm lca s1 s2;
          linearizable lca s1' s2;
          eliminate exists l'. interleaving_predicate l' lca s1' s2
          returns exists l. interleaving_predicate l lca s1 s2
          with _. begin
            let l = Seq.snoc l' op1 in
            introduce exists l. interleaving_predicate l lca s1 s2
            with l
            and begin 
              interleaving_s1_inv_comm lca s1 s2 l'
            end
          end
        end

        else 
          begin
          assert (not (exists_triple last1 (diff (ops_of s2) (ops_of lca))) /\
                 not (exists_triple last2 (diff (ops_of s1) (ops_of lca)))); 
          if First_then_second? (resolve_conflict last1 last2) then
          begin 
            linearizable_s1_gt0_pre lca s1 s2;
            linearizable lca inv1 s2;
            eliminate exists l'. interleaving_predicate l' lca inv1 s2
            returns exists l. interleaving_predicate l lca s1 s2
            with _. begin
              let l = Seq.snoc l' last1 in
              introduce exists l. interleaving_predicate l lca s1 s2
              with l
              and begin
                interleaving_s1_inv lca s1 s2 l'
              end
            end
          end
          
          else
          begin 
            linearizable_s2_gt0_pre lca s1 s2;
            linearizable lca s1 inv2;
            eliminate exists l'. interleaving_predicate l' lca s1 inv2
            returns exists l. interleaving_predicate l lca s1 s2
            with _. begin
              let l = Seq.snoc l' last2 in
              introduce exists l. interleaving_predicate l lca s1 s2
              with l
              and begin
                interleaving_s2_inv lca s1 s2 l'
              end
            end
          end          
        end
      end
#pop-options
