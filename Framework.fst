module Framework

open FStar.Seq
open App

#set-options "--query_stats"

#set-options "--z3rlimit 600 --fuel 1 --ifuel 1"
let rec linearizable (lca s1 s2:st)
  : Lemma 
      (requires 
         is_prefix (ops_of lca) (ops_of s1) /\
         is_prefix (ops_of lca) (ops_of s2) /\
         (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s1) (ops_of lca)) ==> lt id id1) /\
         (forall id id1. mem_id id (ops_of lca) /\ mem_id id1 (diff (ops_of s2) (ops_of lca)) ==> lt id id1) /\
         (forall id. mem_id id (diff (ops_of s1) (ops_of lca)) ==> not (mem_id id (diff (ops_of s2) (ops_of lca)))))
      (ensures 
         concrete_merge_pre (v_of lca) (v_of s1) (v_of s2) /\
         (exists l. interleaving_predicate l lca s1 s2))
      (decreases %[Seq.length (ops_of s1); Seq.length (ops_of s2)])

  = merge_prop lca s1 s2;

    if ops_of s1 = ops_of lca 
    then begin
      linearizable_s1_01 lca s1 s2
    end
    else 
    if Seq.length (ops_of s1) > Seq.length (ops_of lca) && ops_of s2 = ops_of lca
    then begin
      linearizable_s2_01 lca s1 s2
    end
    else begin
        assert (Seq.length (ops_of s1) > Seq.length (ops_of lca)); 
        assert (Seq.length (ops_of s2) > Seq.length (ops_of lca));
        let _, last1 = un_snoc (ops_of s1) in
        let _, last2 = un_snoc (ops_of s2) in

        let inv1 = inverse_st s1 in 
        let inv2 = inverse_st s2 in 

        if last (resolve_conflict last1 last2) = last1 then
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
          assert (last (resolve_conflict last1 last2) <> last1);
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

