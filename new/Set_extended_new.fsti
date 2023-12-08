module Set_extended_new

val t (a:eqtype) : Type0

val empty (#a:eqtype) : t a
val singleton (#a:eqtype) (x:a) : t a
val mem (#a:eqtype) (x:a) (s:t a) : bool
val equal (#a:eqtype) (s1 s2:t a) : Type0
val union (#a:eqtype) (s1 s2:t a) : t a
val intersection (#a:eqtype) (s1 s2:t a) : t a
val difference (#a:eqtype) (s1 s2:t a) : t a
val filter (#a:eqtype) (s:t a) (p:a -> bool) : t a
val remove (#a:eqtype) (s:t a) (x:a) : t a

val mem_empty (#a:eqtype) (x:a)
  : Lemma (not (mem x empty))
          [SMTPat (mem x empty)]

val equal_intro (#a:eqtype) (s1 s2:t a)
  : Lemma (requires (forall (x:a). mem x s1 == mem x s2))
          (ensures equal s1 s2)
          [SMTPat (equal s1 s2)]

val equal_elim (#a:eqtype) (s1 s2:t a)
  : Lemma (requires equal s1 s2)
          (ensures s1 == s2)
          [SMTPat (equal s1 s2)]

let equal_refl (#a:eqtype) (s1 s2:t a)
  : Lemma (requires s1 == s2)
          (ensures (forall (x:a). mem x s1 == mem x s2) /\ equal s1 s2)
          [SMTPat (equal s1 s2)] = ()

// no need to define it, it is already derivable
let equal_refl1 (#a:eqtype) (s:t a)
  : Lemma (equal s s) = ()

let subset (#a:eqtype) (s1:t a) (s2:t a) =
  (forall x. mem x s1 ==> mem x s2)

val mem_subset (#a:eqtype) (s1:t a) (s2:t a)
  : Lemma (requires (forall x. mem x s1 ==> mem x s2))
          (ensures (subset s1 s2))
          [SMTPat (subset s1 s2)]

val subset_mem (#a:eqtype) (s1:t a) (s2:t a)
  : Lemma (requires (subset s1 s2))
          (ensures (forall x. mem x s1 ==> mem x s2))
          [SMTPat (subset s1 s2)]
   
val mem_union (#a:eqtype) (s1 s2:t a) (x:a)
  : Lemma (mem x (union s1 s2) <==> (mem x s1 || mem x s2))
          [SMTPat (mem x (union s1 s2))]

val mem_singleton: #a:eqtype -> x:a -> y:a -> Lemma
   (requires True)
   (ensures (mem y (singleton x) = (x=y)))
   [SMTPat (mem y (singleton x))]
   
let add (#a:eqtype) (x:a) (s:t a) : t a =
  union s (singleton x)

val mem_intersection (#a:eqtype) (s1 s2:t a) (x:a)
  : Lemma (mem x (intersection s1 s2) <==> (mem x s1 /\ mem x s2))
          [SMTPat (mem x (intersection s1 s2))]

val mem_difference (#a:eqtype) (s1 s2:t a) (x:a)
  : Lemma (mem x (difference s1 s2) <==> (mem x s1 /\ ~ (mem x s2)))
          [SMTPat (mem x (difference s1 s2))]
   
val mem_filter (#a:eqtype) (s:t a) (p:a -> bool) (x:a)
  : Lemma (mem x (filter s p) <==> (mem x s /\ p x))
          [SMTPat (mem x (filter s p))]

val mem_remove_x (#a:eqtype) (s:t a) (x:a)
  : Lemma (not (mem x (remove s x)))
          [SMTPat (mem x (remove s x))]

val mem_remove_y (#a:eqtype) (s:t a) (x:a) (y:a)
  : Lemma (requires x =!= y)
          (ensures mem y (remove s x) == mem y s)
          [SMTPat (mem y (remove s x))]
          
(*let forall_s (#a:eqtype) (s:t a) (p:a -> bool) : Type0 =
  filter s p == s

let exists_s (#a:eqtype) (s:t a) (p:a -> bool) : Type0 =
  ~ (filter s p == empty)

val exists_mem (#a:eqtype) (s:t a) (p:a -> bool)
  : Lemma (ensures ((exists_s s p == true) <==> (exists x. mem x s /\ p x)))
    [SMTPat (exists_s s p)]*)
    
(*val t (a:eqtype) : eqtype

val equal (#a:eqtype) (s1:t a) (s2:t a) : Type0

val empty (#a:eqtype) : Tot (t a)

val mem (#a:eqtype) (x:a) (s:t a) : Tot bool

val singleton (#a:eqtype) (x:a) : Tot (t a)

val union      : #a:eqtype -> t a -> t a -> Tot (t a)
val intersect  : #a:eqtype -> t a -> t a -> Tot (t a)
val complement : #a:eqtype -> t a -> Tot (t a)
val difference : #a:eqtype -> t a -> t a -> Tot (t a)

let subset (#a:eqtype) (s1:t a) (s2:t a) =
  forall x. mem x s1 ==> mem x s2

let add (#a:eqtype) (x:a) (s:t a) : t a =
  union s (singleton x)

let remove (#a:eqtype) (x:a) (s:t a) : t a =
  intersect s (complement (singleton x))

(* Properties *)
val mem_empty: #a:eqtype -> x:a -> Lemma
   (requires True)
   (ensures (not (mem x empty)))
   [SMTPat (mem x empty)]

val mem_singleton: #a:eqtype -> x:a -> y:a -> Lemma
   (requires True)
   (ensures (mem y (singleton x) = (x=y)))
   [SMTPat (mem y (singleton x))]

val mem_union: #a:eqtype -> x:a -> s1:t a -> s2:t a -> Lemma
   (requires True)
   (ensures (mem x (union s1 s2) = (mem x s1 || mem x s2)))
   [SMTPat (mem x (union s1 s2))]

val add_mem (#a:eqtype) (x:a) (s:t a)
  : Lemma (requires mem x s)
          (ensures add x s == s)
          [SMTPat (mem x s); SMTPat (add x s)]

val mem_add_x (#a:eqtype) (x:a) (s:t a)
  : Lemma (mem x (add x s))
          [SMTPat (mem x (add x s))]

val mem_add_y (#a:eqtype) (x:a) (s:t a) (y:a)
  : Lemma (requires x =!= y)
          (ensures mem y (add x s) == mem y s)
          [SMTPat (mem y (add x s))]
          
(*val mem_add: #a:eqtype -> x:a -> y:a -> s:t a -> Lemma
   (requires True)
   (ensures (mem x (add y s) = (mem x s || x = y)))
   [SMTPat (mem x (add y s))]*)
   
val mem_intersect: #a:eqtype -> x:a -> s1:t a -> s2:t a -> Lemma
   (requires True)
   (ensures (mem x (intersect s1 s2) = (mem x s1 && mem x s2)))
   [SMTPat (mem x (intersect s1 s2))]

val mem_complement: #a:eqtype -> x:a -> s:t a -> Lemma
   (requires True)
   (ensures (mem x (complement s) = not (mem x s)))
   [SMTPat (mem x (complement s))]

val mem_difference : #a:eqtype -> x:a -> s1:t a -> s2:t a -> Lemma
  (requires True)
  (ensures (mem x (difference s1 s2) <==> (mem x s1 /\ ~ (mem x s2))))
  [SMTPat (mem x (difference s1 s2))]
          
val mem_subset: #a:eqtype -> s1:t a -> s2:t a -> Lemma
   (requires (forall x. mem x s1 ==> mem x s2))
   (ensures (subset s1 s2))
   [SMTPat (subset s1 s2)]

val subset_mem: #a:eqtype -> s1:t a -> s2:t a -> Lemma
   (requires (subset s1 s2))
   (ensures (forall x. mem x s1 ==> mem x s2))
   [SMTPat (subset s1 s2)]

val remove_non_mem (#a:eqtype) (x:a) (s:t a) 
  : Lemma (requires not (mem x s))
          (ensures remove x s == s)
          [SMTPat (remove x s); SMTPat (mem x s)]

val mem_remove_x (#a:eqtype) (x:a) (s:t a) 
  : Lemma (not (mem x (remove x s)))
          [SMTPat (mem x (remove x s))]

val mem_remove_y (#a:eqtype) (x:a) (y:a) (s:t a) 
  : Lemma (requires x =!= y)
          (ensures mem y (remove x s) == mem y s)
          [SMTPat (mem y (remove x s))]
          
val lemma_equal_intro: #a:eqtype -> s1:t a -> s2:t a -> Lemma
    (requires  (forall x. mem x s1 = mem x s2))
    (ensures (equal s1 s2))
    [SMTPat (equal s1 s2)]

val lemma_equal_elim: #a:eqtype -> s1:t a -> s2:t a -> Lemma
    (requires (equal s1 s2))
    (ensures  (s1 == s2))
    [SMTPat (equal s1 s2)]

val lemma_equal_refl: #a:eqtype -> s1:t a -> s2:t a -> Lemma
    (requires (s1 == s2))
    (ensures  (equal s1 s2))
    [SMTPat (equal s1 s2)]
      
val filter (#a:eqtype) (s:t a) (p:a -> bool) : t a

val mem_filter (#a:eqtype) (x:a) (s:t a) (p:a -> bool) 
  : Lemma (mem x (filter s p) <==> (mem x s /\ p x))
          [SMTPat (mem x (filter s p))]

// we can define exists_s rather than val?
let exists_s (#a:eqtype) (s:t a) (p:a -> bool) : bool =
  not (filter s p = empty)

val exists_mem (#a:eqtype) (s:t a) (p:a -> bool)
  : Lemma (ensures ((exists_s s p = true) <==> (exists x. mem x s /\ p x)))
    [SMTPat (exists_s s p)]
    
let forall_s (#a:eqtype) (s:t a) (p:a -> bool) : bool =
  filter s p = s*)
