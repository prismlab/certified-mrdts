module Set_extended

val set (a:eqtype) : eqtype

val mem (#a:eqtype) (x:a) (s:set a) : Tot bool

val empty (#a:eqtype) : set a
val empty_mem (#a:eqtype) (x:a)
  : Lemma (ensures not (mem x empty))
    [SMTPat (mem x empty)]
  
val equal (#a:eqtype) (s1:set a) (s2:set a) : Type0
val equal_mem (#a:eqtype) (s1:set a) (s2:set a)
  : Lemma (ensures (equal s1 s2 <==> (forall e. mem e s1 <==> mem e s2)))
    [SMTPat (equal s1 s2)]

val singleton (#a:eqtype) (x:a) : set a
val singleton_mem (#a:eqtype) (x:a) (y:a) 
  : Lemma (ensures (mem y (singleton x) = (x=y)))
    [SMTPat (mem y (singleton x))]

val add (#a:eqtype) (ele:a) (s:set a) : set a
val add_mem (#a:eqtype) (ele:a) (s:set a) (x:a)
  : Lemma (ensures mem x (add ele s) <==> (mem x s \/ x == ele))
    [SMTPat (mem x (add ele s))]

val union (#a:eqtype) (s1:set a) (s2:set a) : set a
val union_mem (#a:eqtype) (s1:set a) (s2:set a) (x:a)
  : Lemma (ensures mem x (union s1 s2) <==> (mem x s1 \/ mem x s2))
    [SMTPat (mem x (union s1 s2))]

val intersect (#a:eqtype) (s1:set a) (s2:set a) : set a
val intersect_mem (#a:eqtype) (s1:set a) (s2:set a) (x:a)
  : Lemma (ensures mem x (intersect s1 s2) <==> (mem x s1 /\ mem x s2))
    [SMTPat (mem x (intersect s1 s2))]

val remove_if (#a:eqtype) (s:set a) (f:a -> bool) : set a
val remove_if_mem (#a:eqtype) (s:set a) (f:a -> bool) (x:a)
  : Lemma (ensures mem x (remove_if s f) <==> (mem x s /\ ~ (f x))) 
    [SMTPat (mem x (remove_if s f))]

val filter_s (#a:eqtype) (s:set a) (f:a -> bool) : set a
val filter_mem (#a:eqtype) (s:set a) (f:a -> bool) (x:a)
  : Lemma (ensures (mem x (filter_s s f) <==> (mem x s /\ f x)))
    [SMTPat (mem x (filter_s s f))]

val exists_s (#a:eqtype) (s:set a) (f:a -> bool) : bool
val exists_mem (#a:eqtype) (s:set a) (f:a -> bool)
  : Lemma (ensures ((exists_s s f = true) <==> (exists x. mem x s /\ f x)))
    [SMTPat (exists_s s f)]

val forall_s (#a:eqtype) (s:set a) (f:a -> bool) : bool
val forall_mem (#a:eqtype) (s:set a) (f:a -> bool)
  : Lemma (ensures ((forall_s s f = true) <==> (forall x. mem x s ==> f x)))
    [SMTPat (forall_s s f)]

val count (#a:eqtype) (ele:a) (s:set a) : nat
val mem_count (#a:eqtype) (ele:a) (s:set a)
  : Lemma (ensures ((mem ele s = true) <==> count ele s > 0))
    [SMTPat (count ele s)]

val count_if (#a:eqtype) (s:set a) (f:a -> bool) : nat
val mem_count_if (#a:eqtype) (s:set a) (f:a -> bool)
  : Lemma (ensures ((count_if s f > 0) <==> (filter_s s (fun e -> f e) <> empty)))
    [SMTPat (count_if s f)]

val extr (#a:eqtype) (x:option a{Some? x}) : (r:a{x = Some r})

val find_if (#a:eqtype) (s:set a) (f:a -> bool) : option a
val mem_find_if (#a:eqtype) (s:set a) (f:a -> bool)
  : Lemma (ensures (None? (find_if s f) <==> ((forall e. mem e s ==> ~ (f e)) \/ s = empty)) /\
                   (Some? (find_if s f) <==> (exists e. mem e s /\ f e)) /\
                   (Some? (find_if s f) ==> (exists e. mem e s /\ f e /\ e = extr (find_if s f)) /\ (f (extr (find_if s f)))))
    [SMTPat (find_if s f)]

val mem_find_if_exists (#a:eqtype) (s:set a) (f:a -> bool)
  : Lemma (requires (exists e. mem e s /\ f e))
          (ensures (None? (find_if s f) <==> ((forall e. mem e s ==> ~ (f e)) \/ s = empty)) /\
                   (Some? (find_if s f) <==> (exists e. mem e s /\ f e)) /\
                   (Some? (find_if s f) ==> (exists e. mem e s /\ f e /\ e = extr (find_if s f)) /\ (f (extr (find_if s f)))) /\
                   (s <> empty ==> Some? (find_if s f)))
          [SMTPat (find_if s f)]
