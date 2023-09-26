module Set_extended_new

let antisymmetric (#a:eqtype) (f:a -> a -> bool) =
  forall (x y:a). (f x y /\ f y x) ==> x == y

let transitive (#a:eqtype) (f:a -> a -> bool) =
  forall (x y z:a). (f x y /\ f y z) ==> f x z

let comparable (#a:eqtype) (f:a -> a -> bool) =
  forall (x y:a). f x y \/ f y x

type total_order (a:eqtype) = f:(a -> a -> bool) {
  antisymmetric f /\ transitive f /\ comparable f
}

val t (a:eqtype) (f:total_order a) : eqtype

val empty (#a:eqtype) (f:total_order a) : t a f

val mem (#a:eqtype) (#f:_) (x:a) (s:t a f) : bool

val mem_empty (#a:eqtype) (#f:_) (x:a)
  : Lemma (not (mem x (empty f)))
          [SMTPat (mem x (empty f))]

val equal (#a:eqtype) (#f:_) (s1 s2:t a f) : Type0

val equal_intro (#a:eqtype) (#f:_) (s1 s2:t a f)
  : Lemma (requires forall (x:a). mem x s1 == mem x s2)
          (ensures equal s1 s2)
          [SMTPat (equal s1 s2)]

val equal_elim (#a:eqtype) (#f:_) (s1 s2:t a f)
  : Lemma (requires equal s1 s2)
          (ensures s1 == s2)
          [SMTPat (equal s1 s2)]

let equal_refl (#a:eqtype) (#f:_) (s1 s2:t a f)
  : Lemma (requires s1 == s2)
          (ensures (forall (x:a). mem x s1 == mem x s2))
          [SMTPat (equal s1 s2)] = ()
          
// no need to define it, it is already derivable
let equal_refl1 (#a:eqtype) (#f:_) (s:t a f)
  : Lemma (equal s s) = ()

val insert (#a:eqtype) (#f:_) (x:a) (s:t a f) : t a f

val insert_mem (#a:eqtype) (#f:_) (x:a) (s:t a f)
  : Lemma (requires mem x s)
          (ensures insert x s == s)
          [SMTPat (mem x s); SMTPat (insert x s)]

val mem_insert_x (#a:eqtype) (#f:_) (x:a) (s:t a f)
  : Lemma (mem x (insert x s))
          [SMTPat (mem x (insert x s))]

val mem_insert_y (#a:eqtype) (#f:_) (x:a) (s:t a f) (y:a)
  : Lemma (requires x =!= y)
          (ensures mem y (insert x s) == mem y s)
          [SMTPat (mem y (insert x s))]

val union (#a:eqtype) (#f:_) (s1 s2:t a f) : t a f

val mem_union (#a:eqtype) (#f:_) (s1 s2:t a f) (x:a)
  : Lemma (mem x (union s1 s2) <==> (mem x s1 || mem x s2))
          [SMTPat (mem x (union s1 s2))]

val intersection (#a:eqtype) (#f:_) (s1 s2:t a f) : t a f

val mem_intersection (#a:eqtype) (#f:_) (s1 s2:t a f) (x:a)
  : Lemma (mem x (intersection s1 s2) <==> (mem x s1 /\ mem x s2))
          [SMTPat (mem x (intersection s1 s2))]

val difference (#a:eqtype) (#f:_) (s1 s2:t a f) : t a f

val mem_difference (#a:eqtype) (#f:_) (s1 s2:t a f) (x:a)
  : Lemma (mem x (difference s1 s2) <==> (mem x s1 /\ ~ (mem x s2)))
          [SMTPat (mem x (difference s1 s2))]
     
val filter (#a:eqtype) (#f:_) (s:t a f) (p:a -> bool) : t a f

val mem_filter (#a:eqtype) (#f:_) (s:t a f) (p:a -> bool) (x:a)
  : Lemma (mem x (filter s p) <==> (mem x s /\ p x))
          [SMTPat (mem x (filter s p))]

// we can define exists_s rather than val?
let exists_s (#a:eqtype) (#f:_) (s:t a f) (p:a -> bool) : bool =
  not (filter s p = empty f)

val exists_mem (#a:eqtype) (#f:_) (s:t a f) (p:a -> bool)
  : Lemma (ensures ((exists_s s p = true) <==> (exists x. mem x s /\ p x)))
    [SMTPat (exists_s s p)]
    
let forall_s (#a:eqtype) (#f:_) (s:t a f) (p:a -> bool) : bool =
  filter s p = s

let is_min (#a:eqtype) (#f:_) (s:t a f{s =!= empty f}) (x:a) =
  mem x s /\ (forall (y:a). (mem y s /\ x =!= y) ==> f x y)

val min (#a:eqtype) (#f:_) (s:t a f{s =!= empty f}) : x:a{is_min s x}

val remove (#a:eqtype) (#f:_) (s:t a f) (x:a) : t a f

val remove_non_mem (#a:eqtype) (#f:_) (s:t a f) (x:a)
  : Lemma (requires not (mem x s))
          (ensures remove s x == s)
          [SMTPat (remove s x); SMTPat (mem x s)]

val mem_remove_x (#a:eqtype) (#f:_) (s:t a f) (x:a)
  : Lemma (not (mem x (remove s x)))
          [SMTPat (mem x (remove s x))]

val mem_remove_y (#a:eqtype) (#f:_) (s:t a f) (x:a) (y:a)
  : Lemma (requires x =!= y)
          (ensures mem y (remove s x) == mem y s)
          [SMTPat (mem y (remove s x))]

val extract (#a:Type0) (x:option a{Some? x}) : (r:a{x == Some r})
