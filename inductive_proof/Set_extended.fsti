module Set_extended

val set (a:eqtype) : Type0

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
