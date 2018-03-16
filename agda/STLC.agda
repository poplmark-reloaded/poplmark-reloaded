module STLC where

open import Generic

open import Size
open import Data.Sum as Sum
open import Data.Product as Prod
open import Agda.Builtin.List
open import Data.Product hiding (,_)
open import Data.Star as S using (Star)
open import Function hiding (_∋_)
open import Relation.Binary.PropositionalEquality hiding ([_]); open ≡-Reasoning

---------------------------------------------------------------------------------
-- Simply-Typed Lambda Calculus and Type-directed Reduction
---------------------------------------------------------------------------------

-- Definition of the language. We define an enumeration `TermC` as the
-- type of constructor instead of using Booleans. This allows us to have
-- a clearer definition as well as storing the needed type arguments in
-- the constructor itself rather than having to use multiple extra `σ
-- constructors in the Desc.

data Type : Set where
  α    : Type
  _⇒_  : Type → Type → Type

data TermC : Set where
  Lam  : Type → Type → TermC
  App  : Type → Type → TermC

TermD : Desc Type
TermD =  `σ TermC λ where
  (Lam σ τ) → `X (σ ∷ []) τ (`∎ (σ ⇒ τ))
  (App σ τ) → `X [] (σ ⇒ τ) (`X [] σ (`∎ τ))

Term : Type ─Scoped
Term = Tm TermD _

-- We provide handy patterns and DISPLAY rules to hide the encoding
-- our generic-syntax library uses. Unfortunately pattern-synonyms
-- can't yet be typed in Agda.

infixl 10 _`∙_
pattern `λ' b     = (Lam _ _ , b , refl)
pattern _`∙'_ f t = (App _ _ , f , t , refl)
pattern `λ  b     = `con (`λ' b)
pattern _`∙_ f t  = `con (f `∙' t)

{-# DISPLAY syn.`con (Lam _ _ , b , refl)     = `λ b   #-}
{-# DISPLAY syn.`con (App _ _ , f , t , refl) = f `∙ t #-}

-- The Typed Reduction relation can be defined in the usual fashion
-- thanks to the pattern synonyms introduced above. Its reflexive
-- transitive closure is obtained by instantiating the standard
-- library's Star.

infix 3 _⊢_∋_↝_ _⊢_∋_↝⋆_
data _⊢_∋_↝_ Γ : ∀ τ → Term τ Γ → Term τ Γ → Set where
-- computational
  β    : ∀ {σ τ} t (u : Term σ Γ) → Γ ⊢ τ ∋ `λ t `∙ u ↝ t [ u /0]
-- structural
  [λ]  : ∀ {σ τ t u} → (σ ∷ Γ) ⊢ τ ∋ t ↝ u → Γ ⊢ σ ⇒ τ ∋ `λ t ↝ `λ u
  [∙]₁ : ∀ {σ τ t u} f → Γ ⊢ σ ∋ t ↝ u → Γ ⊢ τ ∋ f `∙ t ↝ f `∙ u
  [∙]₂ : ∀ {σ τ f g} → Γ ⊢ σ ⇒ τ ∋ f ↝ g → ∀ t → Γ ⊢ τ ∋ f `∙ t ↝ g `∙ t

_⊢_∋_↝⋆_ : ∀ Γ σ → Term σ Γ → Term σ Γ → Set
Γ ⊢ σ ∋ t ↝⋆ u = Star (Γ ⊢ σ ∋_↝_) t u

-- Stability of Reduction
---------------------------------------------------------------------------------

-- Under Thinning
th^↝ : ∀ {σ Γ Δ t u} ρ → Γ ⊢ σ ∋ t ↝ u → Δ ⊢ σ ∋ ren ρ t ↝ ren ρ u
th^↝ ρ (β t u)    = subst (_ ⊢ _ ∋ ren ρ (`λ t `∙ u) ↝_) (sym $ renβ TermD t u ρ) (β _ _)
th^↝ ρ ([λ] r)    = [λ] (th^↝ _ r)
th^↝ ρ ([∙]₁ f r) = [∙]₁ (ren ρ f) (th^↝ ρ r)
th^↝ ρ ([∙]₂ r t) = [∙]₂ (th^↝ ρ r) (ren ρ t)

-- Under Substitution (term reduces)
sub^↝ : ∀ {σ Γ Δ t u} ρ → Γ ⊢ σ ∋ t ↝ u → Δ ⊢ σ ∋ sub ρ t ↝ sub ρ u
sub^↝ ρ (β t u)    = subst (_ ⊢ _ ∋ sub ρ (`λ t `∙ u) ↝_) (sym $ subβ TermD t u ρ) (β _ _)
sub^↝ ρ ([λ] r)    = [λ] (sub^↝ _ r)
sub^↝ ρ ([∙]₁ f r) = [∙]₁ (sub ρ f) (sub^↝ ρ r)
sub^↝ ρ ([∙]₂ r t) = [∙]₂ (sub^↝ ρ r) (sub ρ t)

[/0]^↝ : ∀ {σ τ Γ b b′} → (σ ∷ Γ) ⊢ τ ∋ b ↝ b′ → ∀ u → Γ ⊢ τ ∋ b [ u /0] ↝ b′ [ u /0]
[/0]^↝ r u = sub^↝ (u /0]) r

-- Under Substitution (substitution reduces)
-- Here we use generic-syntax's Simulation result: related inputs yield related outputs

↝⋆^R : Rel Term Term
rel ↝⋆^R = _ ⊢ _ ∋_↝⋆_

[v↦t↝⋆t] : ∀ {Γ Δ} {ρ : (Γ ─Env) Term Δ} → rel.∀[ ↝⋆^R ] ρ ρ
lookup^R [v↦t↝⋆t] k = S.ε

sub^↝⋆ : ∀ {σ Γ Δ} (t : Term σ Γ) {ρ ρ′} →
         rel.∀[ ↝⋆^R ] ρ ρ′ → Δ ⊢ σ ∋ sub ρ t ↝⋆ sub ρ′ t
sub^↝⋆ t ρ^R = Sim.sim sim ρ^R t where

  sim : Sim ↝⋆^R ↝⋆^R TermD Substitution Substitution
  Sim.th^R  sim = λ ρ → S.gmap _ (th^↝ ρ)
  Sim.var^R sim = id
  Sim.alg^R sim = λ where
    (f `∙' t) {ρ₁} {ρ₂} ρ^R (refl , f^R , t^R , _) → S.gmap _ (λ f → [∙]₂ f (sub ρ₁ t)) f^R
                                                S.◅◅ S.gmap _ ([∙]₁ (sub ρ₂ f)) t^R
    (`λ' b) ρ^R (refl , b^R , _) → S.gmap `λ [λ] (b^R _ [v↦t↝⋆t])

[/0]^↝⋆ : ∀ {σ τ Γ} t {u u′} → Γ ⊢ σ ∋ u ↝ u′ → Γ ⊢ τ ∋ t [ u /0] ↝⋆ t [ u′ /0]
[/0]^↝⋆ t r = sub^↝⋆ t ([v↦t↝⋆t] ∙^R S.return r)

---------------------------------------------------------------------------------
-- Inversion Lemmas: Interaction Between Thinning, Term Constructors & Reductions
---------------------------------------------------------------------------------

-- Thinning & App
th⁻¹^`∙ : ∀ {σ τ Γ Δ} (u : Term τ Γ) {f : Term (σ ⇒ τ) Δ} {t} ρ → f `∙ t ≡ ren ρ u →
          ∃ λ f′ → ∃ λ t′ → f′ `∙ t′ ≡ u × f ≡ ren ρ f′ × t ≡ ren ρ t′
th⁻¹^`∙ (`var _)   ρ ()
th⁻¹^`∙ (`λ _)     ρ ()
th⁻¹^`∙ (f′ `∙ t′) ρ refl = f′ , t′ , refl , refl , refl

-- Thinning & Lam
th⁻¹^`λ : ∀ {σ τ Γ Δ} (u : Term (σ ⇒ τ) Γ) {b : Term τ (σ ∷ Δ)} ρ → `λ b ≡ ren ρ u →
          ∃ λ b′ → `λ b′ ≡ u × b ≡ ren (lift vl^Var (σ ∷ []) ρ) b′
th⁻¹^`λ (`var _) ρ ()
th⁻¹^`λ (_ `∙ _) ρ ()
th⁻¹^`λ (`λ b′)  ρ refl = b′ , refl , refl

-- Thinning & Red
th⁻¹^↝ : ∀ {σ Γ Δ u′} t ρ → Δ ⊢ σ ∋ ren ρ t ↝ u′ →
          ∃ λ u → u′ ≡ ren ρ u × Γ ⊢ σ ∋ t ↝ u
th⁻¹^↝ (`var v) ρ ()
th⁻¹^↝ (`λ b `∙ t) ρ (β _ _) = b [ t /0] , sym (renβ TermD b t ρ) , β b t
th⁻¹^↝ (`λ t)      ρ ([λ] r) =
  let (t′ , eq , r′) = th⁻¹^↝ t _ r in `λ t′ , cong `λ eq , [λ] r′
th⁻¹^↝ (f `∙ t) ρ ([∙]₁ ._ r) =
  let (t′ , eq , r′) = th⁻¹^↝ t ρ r in f `∙ t′ , cong (ren ρ f `∙_) eq , [∙]₁ _ r′
th⁻¹^↝ (f `∙ t) ρ ([∙]₂ r ._) =
  let (f′ , eq , r′) = th⁻¹^↝ f ρ r in f′ `∙ t , cong (_`∙ ren ρ t) eq , [∙]₂ r′ _

-- Thinning and Reds
th⁻¹^↝⋆ : ∀ {σ Γ Δ u′} t ρ → Δ ⊢ σ ∋ ren ρ t ↝⋆ u′ →
          ∃ λ u → u′ ≡ ren ρ u × Γ ⊢ σ ∋ t ↝⋆ u
th⁻¹^↝⋆ {σ} t ρ rs = go t ρ refl rs where

  go : ∀ {Γ Δ} t ρ → ∀ {t′ u′} → t′ ≡ ren ρ t → Δ ⊢ σ ∋ t′ ↝⋆ u′ →
       ∃ λ u → u′ ≡ ren ρ u × Γ ⊢ σ ∋ t ↝⋆ u
  go t ρ refl Star.ε        = t , refl , Star.ε
  go t ρ refl (r Star.◅ rs) =
    let (u , eq , r′)   = th⁻¹^↝ t ρ r in
    let (v , eq′ , rs′) = go u ρ eq rs in
    v , eq′ , r′ Star.◅ rs′

---------------------------------------------------------------------------------
-- Defining Strongly Normalizing Terms
---------------------------------------------------------------------------------

-- Definition of Strong Normalization via Accessibility Relation
-- Inductive definition of Strong Normalisation as the least set of
-- terms closed under reduction

Closed : ∀ {σ Γ} → (Term σ Γ → Term σ Γ → Set) →
         (Term σ Γ → Set) → Term σ Γ → Set
Closed red R t = ∀ {u} → red t u → R u

infix 3 _⊢sn_∋_<_ _⊢sn_∋_
data _⊢sn_∋_<_ Γ σ (t : Term σ Γ) : Size → Set where
  sn : ∀ {i} → Closed (Γ ⊢ σ ∋_↝_) (Γ ⊢sn σ ∋_< i) t → Γ ⊢sn σ ∋ t < ↑ i

_⊢sn_∋_ = _⊢sn_∋_< _

Closed-sn : ∀ {σ Γ t} → Γ ⊢sn σ ∋ t → Closed (Γ ⊢ σ ∋_↝_) (Γ ⊢sn σ ∋_) t
Closed-sn (sn t^SN) = t^SN

-- Properties of sn
---------------------------------------------------------------------------------

-- Closure under ↝⋆
Closed⋆-sn : ∀ {σ Γ t} → Γ ⊢sn σ ∋ t → Closed (Γ ⊢ σ ∋_↝⋆_) (Γ ⊢sn σ ∋_) t
Closed⋆-sn t^SN Star.ε        = t^SN
Closed⋆-sn t^SN (r Star.◅ rs) = Closed⋆-sn (Closed-sn t^SN r) rs

-- Thinning of strongly normalizing terms
th^sn : ∀ {σ Γ Δ t} ρ → Γ ⊢sn σ ∋ t → Δ ⊢sn σ ∋ ren ρ t
th^sn ρ (sn t^SN) = sn $ λ r →
  let (_ , eq , r′) = th⁻¹^↝ _ ρ r
  in subst (_ ⊢sn _ ∋_) (sym eq) $ th^sn ρ (t^SN r′)

-- Anti-Thinning (Strengthening) of strongly normalizing terms
th⁻¹^sn : ∀ {σ Γ Δ t} ρ → Δ ⊢sn σ ∋ ren ρ t → Γ ⊢sn σ ∋ t
th⁻¹^sn ρ (sn tρ^sn) = sn (λ r → th⁻¹^sn ρ (tρ^sn (th^↝ ρ r)))

-- Anti-Substitution
sub⁻¹^sn : ∀ {σ Γ Δ} t ρ → Δ ⊢sn σ ∋ (sub ρ t) → Γ ⊢sn σ ∋ t
sub⁻¹^sn t ρ (sn tρ^sn) = sn (λ r → sub⁻¹^sn _ ρ (tρ^sn (sub^↝ ρ r)))

[/0]⁻¹^sn : ∀ {σ τ Γ} t u → Γ ⊢sn τ ∋ (t [ u /0]) → (σ ∷ Γ) ⊢sn τ ∋ t
[/0]⁻¹^sn t u t[u]^sn = sub⁻¹^sn t (u /0]) t[u]^sn

-- Closure under Lam
`λ^sn : ∀ {σ τ Γ t} → (σ ∷ Γ) ⊢sn τ ∋ t → Γ ⊢sn σ ⇒ τ ∋ `λ t
`λ^sn (sn t^R) = sn λ { ([λ] r) → `λ^sn (t^R r) }

-- Closure under Anti-App
`∙t⁻¹^sn : ∀ {σ τ Γ f t i} → Γ ⊢sn τ ∋ (f `∙ t) < i → Γ ⊢sn σ ⇒ τ ∋ f < i
`∙t⁻¹^sn (sn ft^sn) = sn (λ r → `∙t⁻¹^sn (ft^sn ([∙]₂ r _)))

f`∙⁻¹^sn : ∀ {σ τ Γ f t i} → Γ ⊢sn τ ∋ (f `∙ t) < i → Γ ⊢sn σ ∋ t < i
f`∙⁻¹^sn (sn ft^sn) = sn (λ r → f`∙⁻¹^sn (ft^sn ([∙]₁ _ r)))

`∙⁻¹^sn : ∀ {σ τ Γ f t i} → Γ ⊢sn τ ∋ (f `∙ t) < i → Γ ⊢sn σ ⇒ τ ∋ f < i × Γ ⊢sn σ ∋ t < i
`∙⁻¹^sn ft^sn = `∙t⁻¹^sn ft^sn , f`∙⁻¹^sn ft^sn

-- Closure under Anti-Lam
`λ⁻¹^sn : ∀ {σ τ Γ t i} → Γ ⊢sn σ ⇒ τ ∋ `λ t < i → (σ ∷ Γ) ⊢sn τ ∋ t < i
`λ⁻¹^sn (sn λt^sn) = sn (λ r → `λ⁻¹^sn (λt^sn ([λ] r)))

---------------------------------------------------------------------------------
-- Evaluation Contexts Indexed by the Scope, the Hole and the Result's Type
---------------------------------------------------------------------------------

infix 3 _∣_⊢_ _∣_⊢sn_∋_
data _∣_⊢_ Γ α : Type → Set where
  <>  : Γ ∣ α ⊢ α
  app : ∀ {σ τ} → Γ ∣ α ⊢ σ ⇒ τ → Term σ Γ → Γ ∣ α ⊢ τ

-- Plugging a Hole
cut : ∀ {Γ α σ} → Term α Γ → Γ ∣ α ⊢ σ → Term σ Γ
cut t <>        = t
cut t (app c u) = cut t c `∙ u

-- Composition of Evaluation Contexts
_∘C_ : ∀ {Γ α β σ} → Γ ∣ β ⊢ σ → Γ ∣ α ⊢ β → Γ ∣ α ⊢ σ
<>      ∘C c′ = c′
app c t ∘C c′ = app (c ∘C c′) t

cut-∘C : ∀ {Γ α β σ} t (c : Γ ∣ β ⊢ σ) (c′ : Γ ∣ α ⊢ β) →
         cut (cut t c′) c ≡ cut t (c ∘C c′)
cut-∘C t <>        c′ = refl
cut-∘C t (app c u) c′ = cong (_`∙ u) (cut-∘C t c c′)

-- Notion of sn for Evaluation Contexts
data _∣_⊢sn_∋_ Γ α : ∀ τ (c : Γ ∣ α ⊢ τ) → Set where
  <>  : Γ ∣ α ⊢sn α ∋ <>
  app : ∀ {σ τ c t} → Γ ∣ α ⊢sn σ ⇒ τ ∋ c → Γ ⊢sn σ ∋ t → Γ ∣ α ⊢sn τ ∋ app c t

∘C^sn : ∀ {Γ α β σ c c′} → Γ ∣ β ⊢sn σ ∋ c → Γ ∣ α ⊢sn β ∋ c′ → Γ ∣ α ⊢sn σ ∋ c ∘C c′
∘C^sn <>              c′^sn = c′^sn
∘C^sn (app c^sn t^sn) c′^sn = app (∘C^sn c^sn c′^sn) t^sn

-- Closure of Reduction under Hole Plugging
cut^↝ : ∀ {Γ α σ t u} c → Γ ⊢ α ∋ t ↝ u → Γ ⊢ σ ∋ cut t c ↝ cut u c
cut^↝ <>        r = r
cut^↝ (app c t) r = [∙]₂ (cut^↝ c r) t

cut^↝⋆ : ∀ {Γ α σ t u} c → Γ ⊢ α ∋ t ↝⋆ u → Γ ⊢ σ ∋ cut t c ↝⋆ cut u c
cut^↝⋆ c = S.gmap (flip cut c) (cut^↝ c)

-- Closure of sn under Anti-Plugging
cut⁻¹^sn : ∀ {Γ α σ} t c → Γ ⊢sn σ ∋ cut t c → (Γ ∣ α ⊢sn σ ∋ c) × (Γ ⊢sn α ∋ t)
cut⁻¹^sn t <>        t^sn     = <> , t^sn
cut⁻¹^sn t (app c u) c[t]u^sn =
  let (c[t]^sn , u^sn) = `∙⁻¹^sn c[t]u^sn in
  let (c^sn , t^sn) = cut⁻¹^sn t c c[t]^sn in
  app c^sn u^sn , t^sn

-- Inversion Lemma: Reduction in the Evaluation Context
cut⁻¹^↝ : ∀ {Γ α σ u} c {v : Var α Γ} → Γ ⊢ σ ∋ cut (`var v) c ↝ u →
          ∃ λ c′ → u ≡ cut (`var v) c′
cut⁻¹^↝ (app <> t) ([∙]₁ _ r)  = app <> _ , refl
cut⁻¹^↝ (app c t)  ([∙]₁ _ r)  = app c _ , refl
cut⁻¹^↝ (app c t)  ([∙]₂ r .t) =
  let (c′ , r′) = cut⁻¹^↝ c r in app c′ _ , cong (_`∙ _) r′
cut⁻¹^↝ <>         ()

-- Closure of sn for Neutrals
`var^sne : ∀ {σ Γ} v → Γ ⊢sn σ ∋ `var v
`var^sne v = sn (λ ())

`∙^sne : ∀ {Γ α σ τ t} {v : Var α Γ} c → Γ ⊢sn σ ⇒ τ ∋ cut (`var v) c → Γ ⊢sn σ ∋ t →
         Γ ⊢sn τ ∋ cut (`var v) (app c t)
`∙^sne c f^sne t^sn = sn (go c f^sne t^sn) where

  go : ∀ {Γ α σ τ t} {v : Var α Γ} c → Γ ⊢sn σ ⇒ τ ∋ cut (`var v) c → Γ ⊢sn σ ∋ t →
       Closed (Γ ⊢ τ ∋_↝_) (Γ ⊢sn τ ∋_) (cut (`var v) (app c t))
  go <>        f^sne      t^sn      ([∙]₂ () t)
  go c         f^sne      (sn t^sn) ([∙]₁ _ r) = sn (go c f^sne (t^sn r))
  go c         (sn f^sne) t^sn      ([∙]₂ r t) =
    let (c′ , eq) = cut⁻¹^↝ c r in
    let r′ = subst (_ ⊢ _ ∋ _ ↝_) eq r in
    subst (λ g → _ ⊢sn _ ∋ g `∙ t) (sym eq) (sn (go c′ (f^sne r′) t^sn))

cut^sn : ∀ {Γ α σ} v {c} → Γ ∣ α ⊢sn σ ∋ c → Γ ⊢sn σ ∋ cut (`var v) c
cut^sn v           <>              = `var^sne v
cut^sn v {app c t} (app c^sn t^sn) = `∙^sne c (cut^sn v c^sn) t^sn

-- Closure of sn under β-Expansion below Evaluation Contexts
---------------------------------------------------------------------------------

data ¬λ {Γ σ} : Term σ Γ → Set where
  var : ∀ v → ¬λ (`var v)
  app : ∀ {τ} f (t : Term τ Γ) → ¬λ (f `∙ t)

cut⁻¹‿sn^↝ : ∀ {Γ α σ u c t} → Γ ∣ α ⊢sn σ ∋ c → ¬λ t → Γ ⊢ σ ∋ cut t c ↝ u →
               (∃ λ t′ → u ≡ cut t′ c × Γ ⊢ α ∋ t ↝ t′)
             ⊎ (∃ λ c′ → u ≡ cut t c′ × Γ ∣ α ⊢sn σ ∋ c′
               × ∀ t′ → Γ ⊢ σ ∋ cut t′ c ↝ cut t′ c′)
cut⁻¹‿sn^↝ <>                        ¬λ r          = inj₁ (_ , refl , r)
cut⁻¹‿sn^↝ (app <> t^sn)             () (β b t)
cut⁻¹‿sn^↝ (app <> t^sn)             ¬λ ([∙]₁ f r) =
  inj₂ (app <> _ , refl , app <> (Closed-sn t^sn r) , λ u → [∙]₁ _ r)
cut⁻¹‿sn^↝ (app <> t^sn)             ¬λ ([∙]₂ r t) = inj₁ (_ , refl , r)
cut⁻¹‿sn^↝ (app c^sn@(app _ _) t^sn) ¬λ ([∙]₁ _ r) =
  inj₂ (_ , refl , app c^sn (Closed-sn t^sn r) , λ u → [∙]₁ _ r)
cut⁻¹‿sn^↝ (app c^sn t^sn)           ¬λ ([∙]₂ r t) with cut⁻¹‿sn^↝ c^sn ¬λ r
... | inj₁ (t′ , eq , r′)         = inj₁ (t′ , cong (_`∙ t) eq , r′)
... | inj₂ (c′ , eq , c′^sn , r′) =
  inj₂ (app c′ t , cong (_`∙ t) eq , app c′^sn t^sn , λ u → [∙]₂ (r′ u) t)

β⁻¹^Closed-sn : ∀ {Γ α σ τ} c b u → (σ ∷ Γ) ⊢sn α ∋ b → Γ ⊢sn σ ∋ u →
                Γ ⊢sn τ ∋ cut (b [ u /0]) c → Γ ∣ α ⊢sn τ ∋ c →
                Closed (Γ ⊢ τ ∋_↝_) (Γ ⊢sn τ ∋_) (cut (`λ b `∙ u) c)
β⁻¹^Closed-sn c b u b^sn@(sn b^sn′) u^sn@(sn u^sn′) c[b[u]]^sn@(sn c[b[u]]^sn′) c^sn r
  with cut⁻¹‿sn^↝ c^sn (app (`λ b) u) r
... | inj₁ (._ , refl , β .b .u)          = c[b[u]]^sn
... | inj₁ (._ , refl , [∙]₁ .(`λ b) r′)  =
  let c[b[u]]^sn′ = Closed⋆-sn c[b[u]]^sn (cut^↝⋆ c ([/0]^↝⋆ b r′)) in
  sn (β⁻¹^Closed-sn c b _ b^sn (u^sn′ r′) c[b[u]]^sn′ c^sn)
... | inj₁ (._ , refl , [∙]₂ ([λ] r′) .u) =
  sn (β⁻¹^Closed-sn c _ u (b^sn′ r′) u^sn (c[b[u]]^sn′ (cut^↝ c ([/0]^↝ r′ u))) c^sn)
... | inj₂ (c′ , refl , c′^sn , r′) =
  sn (β⁻¹^Closed-sn c′ b u b^sn u^sn (c[b[u]]^sn′ (r′ (b [ u /0]))) c′^sn)

β⁻¹^sn : ∀ {Γ α σ τ b u c} → (σ ∷ Γ) ⊢sn α ∋ b → Γ ⊢sn σ ∋ u →
         Γ ⊢sn τ ∋ cut (b [ u /0]) c → Γ ∣ α ⊢sn τ ∋ c →
         Γ ⊢sn τ ∋ cut (`λ b `∙ u) c
β⁻¹^sn b^sn u^sn c[b[u]]^sn c^sn = sn (β⁻¹^Closed-sn _ _ _ b^sn u^sn c[b[u]]^sn c^sn)


---------------------------------------------------------------------------------
-- Inductive Definition of Strongly Normalizing Terms
---------------------------------------------------------------------------------

infix 5 _⊢_∋_↝SN_<_ _⊢SN_∋_<_ _⊢SNe_∋_<_
data _⊢_∋_↝SN_<_ Γ τ : Term τ Γ → Term τ Γ → Size → Set
data _⊢SN_∋_<_ (Γ : List Type) : (σ : Type) → Term σ Γ → Size → Set
data _⊢SNe_∋_<_ (Γ : List Type) : (σ : Type) → Term σ Γ → Size → Set

data _⊢_∋_↝SN_<_ Γ τ where
-- computational
  β    : ∀ {σ i} t u → Γ ⊢SN σ ∋ u < i → Γ ⊢ τ ∋ `λ t `∙ u ↝SN t [ u /0] < ↑ i
-- structural
  [∙]₂ : ∀ {σ i f g} → Γ ⊢ σ ⇒ τ ∋ f ↝SN g < i → ∀ t → Γ ⊢ τ ∋ f `∙ t ↝SN g `∙ t < ↑ i

data _⊢SN_∋_<_ Γ where
  neu : ∀ {σ t i} → Γ ⊢SNe σ ∋ t < i → Γ ⊢SN σ ∋ t < ↑ i
  lam : ∀ {σ τ b i} → (σ ∷ Γ) ⊢SN τ ∋ b < i → Γ ⊢SN σ ⇒ τ ∋ `λ b < ↑ i
  red : ∀ {σ t t′ i} → Γ ⊢ σ ∋ t ↝SN t′ < i → Γ ⊢SN σ ∋ t′ < i → Γ ⊢SN σ ∋ t < ↑ i

data _⊢SNe_∋_<_ Γ where
  var : ∀ {σ i} v → Γ ⊢SNe σ ∋ `var v < ↑ i
  app : ∀ {σ τ f t i} → Γ ⊢SNe σ ⇒ τ ∋ f < i → Γ ⊢SN σ ∋ t < i → Γ ⊢SNe τ ∋ f `∙ t < ↑ i

infix 5 _⊢_∋_↝SN_ _⊢SN_∋_ _⊢SNe_∋_
_⊢_∋_↝SN_ = _⊢_∋_↝SN_< _
_⊢SN_∋_ = _⊢SN_∋_< _
_⊢SNe_∋_ = _⊢SNe_∋_< _

SN∋ : Pred Term
pred SN∋ = _ ⊢SN _ ∋_

SNe : Pred Term
pred SNe = _ ⊢SNe _ ∋_

[v↦v]^SNe : ∀ {Γ} → pred.∀[ SNe ] (base vl^Tm {Γ})
lookup^P [v↦v]^SNe v rewrite lookup-base^Tm {d = TermD} v = var v

-- Notion of SN for Evaluation Contexts
infix 4 _∣_⊢SN_∋_<_ _∣_⊢SN_∋_
data _∣_⊢SN_∋_<_ Γ α : ∀ σ → Γ ∣ α ⊢ σ → Size → Set where
  <>  : ∀ {i} → Γ ∣ α ⊢SN α ∋ <> < ↑ i
  app : ∀ {i σ τ c t} → Γ ∣ α ⊢SN σ ⇒ τ ∋ c < i → Γ ⊢SN σ ∋ t < i → Γ ∣ α ⊢SN τ ∋ app c t < ↑ i

_∣_⊢SN_∋_ = _∣_⊢SN_∋_< _

-- Inversion Lemma: SNe to SN Evaluation Context
cut⁻¹^SNe : ∀ {Γ τ t i} → Γ ⊢SNe τ ∋ t < i → ∃ λ ctx → let (σ , c) = ctx in
            ∃ λ v → t ≡ cut (`var v) c × Γ ∣ σ ⊢SN τ ∋ c < i
cut⁻¹^SNe (var v)          = _ , v , refl , <>
cut⁻¹^SNe (app f^SNe t^SN) =
  let (_ , v , eq , c^SN) = cut⁻¹^SNe f^SNe
  in _ , v , cong (_`∙ _) eq , app c^SN t^SN


-- Stability of SN under Thinning
mutual

 th^SN : ∀ {σ Γ Δ t} ρ → Γ ⊢SN σ ∋ t → Δ ⊢SN σ ∋ ren ρ t
 th^SN ρ (neu n)   = neu (th^SNe ρ n)
 th^SN ρ (lam t)   = lam (th^SN _ t)
 th^SN ρ (red r t) = red (th^↝SN ρ r) (th^SN ρ t)

 th^SNe : ∀ {σ Γ Δ t} ρ → Γ ⊢SNe σ ∋ t → Δ ⊢SNe σ ∋ ren ρ t
 th^SNe ρ (var v)   = var (lookup ρ v)
 th^SNe ρ (app n t) = app (th^SNe ρ n) (th^SN ρ t)

 th^↝SN : ∀ {σ Γ Δ t u} ρ → Γ ⊢ σ ∋ t ↝SN u → Δ ⊢ σ ∋ ren ρ t ↝SN ren ρ u
 th^↝SN ρ (β t u u^SN) = subst (_ ⊢ _ ∋ ren ρ (`λ t `∙ u) ↝SN_< _) (sym $ renβ TermD t u ρ)
                       $ β _ (ren ρ u) (th^SN ρ u^SN)
 th^↝SN ρ ([∙]₂ r t)   = [∙]₂ (th^↝SN ρ r) (ren ρ t)

-- Stability of SN under Anti-Thinning
mutual

 th⁻¹^SN : ∀ {σ Γ Δ t′} t ρ → t′ ≡ ren ρ t → Δ ⊢SN σ ∋ t′ → Γ ⊢SN σ ∋ t
 th⁻¹^SN t        ρ eq    (neu pr)    = neu (th⁻¹^SNe t ρ eq pr)
 th⁻¹^SN (`λ t)   ρ refl  (lam pr)    = lam (th⁻¹^SN t _ refl pr)
 th⁻¹^SN t        ρ refl  (red r pr)  =
   let (t′ , eq , r′) = th⁻¹^↝SN t ρ r in red r′ (th⁻¹^SN t′ ρ eq pr)
 th⁻¹^SN (`var v) ρ ()    (lam pr)
 th⁻¹^SN (f `∙ t) ρ ()    (lam pr)

 th⁻¹^SNe : ∀ {σ Γ Δ t′} t ρ → t′ ≡ ren ρ t → Δ ⊢SNe σ ∋ t′ → Γ ⊢SNe σ ∋ t
 th⁻¹^SNe (`var v) ρ refl (var _)     = var v
 th⁻¹^SNe (f `∙ t) ρ refl (app rf rt) =
  app (th⁻¹^SNe f ρ refl rf) (th⁻¹^SN t ρ refl rt)

 th⁻¹^↝SN : ∀ {σ Γ Δ u} t ρ → Δ ⊢ σ ∋ ren ρ t ↝SN u → ∃ λ u′ → u ≡ ren ρ u′ × Γ ⊢ σ ∋ t ↝SN u′

 th⁻¹^↝SN (`var v) ρ ()
 th⁻¹^↝SN (`λ b)   ρ ()
 th⁻¹^↝SN (`λ b `∙ t) ρ (β ._ ._ t^SN) = b [ t /0] , sym (renβ TermD b t ρ) , β b t (th⁻¹^SN t ρ refl t^SN)
 th⁻¹^↝SN (f `∙ t)    ρ ([∙]₂ r ._)    =
   let (g , eq , r′) = th⁻¹^↝SN f ρ r in g `∙ t , cong (_`∙ ren ρ t) eq , [∙]₂ r′ t

-- SNe Closed under Application
_SNe∙_ : ∀ {Γ σ τ f t} → Γ ⊢SNe σ ⇒ τ ∋ f → Γ ⊢SN σ ∋ t → Γ ⊢SN τ ∋ f `∙ t
f^SNe SNe∙ t^SN = neu (app f^SNe t^SN)

-- Extensionality of SN
SNe-ext : ∀ {Γ σ τ f} v → Γ ⊢SNe τ ∋ f `∙ `var v → Γ ⊢SNe σ ⇒ τ ∋ f
SNe-ext v (app f^SNe v^SN) = f^SNe

SN-ext : ∀ {Γ σ τ f} v → Γ ⊢SN τ ∋ f `∙ `var v → Γ ⊢SN σ ⇒ τ ∋ f
SN-ext v (neu fv^SNe)   = neu (SNe-ext v fv^SNe)
SN-ext v (red ([∙]₂ r .(`var v))   fv^SN) = red r (SN-ext v fv^SN)
SN-ext v (red (β t .(`var v) v^SN) fv^SN) = lam (th⁻¹^SN t (base vl^Var ∙ v) eq fv^SN) where
  eq = sym $ Sim.sim sim.RenSub (base^VarTm^R ∙^R refl) t

---------------------------------------------------------------------------------
-- Soundness: SN implies sn
---------------------------------------------------------------------------------

-- Closure of sn under head β-Expansion
infix 4 _⊢_∋_↝sn_<_ _⊢_∋_↝sn_
data _⊢_∋_↝sn_<_ Γ τ : (t u : Term τ Γ) → Size → Set where
  β    : ∀ {σ i} b u → Γ ⊢sn σ ∋ u → Γ ⊢ τ ∋ `λ b `∙ u ↝sn b [ u /0] < ↑ i
  [∙]₂ : ∀ {σ f g i} → Γ ⊢ σ ⇒ τ ∋ f ↝sn g < i → ∀ t → Γ ⊢ τ ∋ f `∙ t ↝sn g `∙ t < ↑ i

_⊢_∋_↝sn_ = _⊢_∋_↝sn_< _

↝sn⁻¹^sn : ∀ {Γ σ τ t′ t i} c → Γ ⊢ σ ∋ t′ ↝sn t < i →
           Γ ⊢sn τ ∋ cut t c → Γ ⊢sn τ ∋ cut t′ c
↝sn⁻¹^sn c (β b u u^sn)  c[b[u]]^sn =
  let (c^sn , b[u]^sn) = cut⁻¹^sn (b [ u /0]) c c[b[u]]^sn in
  let b^sn = [/0]⁻¹^sn b u b[u]^sn in
  β⁻¹^sn b^sn u^sn c[b[u]]^sn c^sn
↝sn⁻¹^sn c ([∙]₂ r^sn u) c[ft]^sn   =
  let eq t   = cut-∘C t c (app <> u) in
  let ft^sn′ = subst (_ ⊢sn _ ∋_) (eq _) c[ft]^sn in
  let ih     = ↝sn⁻¹^sn (c ∘C app <> u) r^sn ft^sn′ in
  subst (_ ⊢sn _ ∋_) (sym (eq _)) ih

-- Soundness of SN
mutual

 sound^SN : ∀ {Γ σ t i} → Γ ⊢SN σ ∋ t < i → Γ ⊢sn σ ∋ t
 sound^SN (neu t^SNe)  = let (_ , v , eq , c^SN) = cut⁻¹^SNe t^SNe in
                         subst (_ ⊢sn _ ∋_) (sym eq) (cut^sn _ (sound^∣SN c^SN))
 sound^SN (lam b^SN)   = `λ^sn (sound^SN b^SN)
 sound^SN (red r t^SN) = ↝sn⁻¹^sn <> (sound^↝SN r) (sound^SN t^SN)

 sound^∣SN : ∀ {Γ α σ c i} → Γ ∣ α ⊢SN σ ∋ c < i → Γ ∣ α ⊢sn σ ∋ c
 sound^∣SN <>              = <>
 sound^∣SN (app c^SN t^SN) = app (sound^∣SN c^SN) (sound^SN t^SN)

 sound^↝SN : ∀ {Γ σ t u i} → Γ ⊢ σ ∋ t ↝SN u < i → Γ ⊢ σ ∋ t ↝sn u
 sound^↝SN (β t u u^SN) = β t u (sound^SN u^SN)
 sound^↝SN ([∙]₂ r t)   = [∙]₂ (sound^↝SN r) t


---------------------------------------------------------------------------------
-- Completeness: sn implies SN
---------------------------------------------------------------------------------

mutual
  complete^SNe : ∀ {Γ σ α i c} v → Γ ∣ α ⊢SN σ ∋ c →
                 let t = cut (`var v) c in
                 ∀ {t′} → t′ ≡ t → Γ ⊢sn σ ∋ t′ < i → Γ ⊢SNe σ ∋ t′
  complete^SNe v <>           refl c[v]^sn   = var v
  complete^SNe v (app c t^SN) refl c[v]∙t^sn =
    let (c[v]^sn , t^sn) = `∙⁻¹^sn c[v]∙t^sn in
    app (complete^SNe v c refl c[v]^sn) t^SN

  complete^SN-β : ∀ {Γ σ τ α i} (b : Term α (σ ∷ Γ)) u (c : Γ ∣ α ⊢ τ) →
                  let t = cut (`λ b `∙ u) c in Γ ⊢ τ ∋ t ↝SN cut (b [ u /0]) c →
                  ∀ {t′} → t′ ≡ t → Γ ⊢sn τ ∋ t′ < i → Γ ⊢SN τ ∋ t′
  complete^SN-β b u c r refl (sn c[λb∙u]^sn) = red r (complete^SN _ (c[λb∙u]^sn (cut^↝ c (β b u))))

  complete^SN : ∀ {Γ σ i} t → Γ ⊢sn σ ∋ t < i → Γ ⊢SN σ ∋ t
  complete^SN (`var v) v^sn  = neu (var v)
  complete^SN (`λ b)   λb^sn = lam (complete^SN b (`λ⁻¹^sn λb^sn))
  complete^SN (f `∙ t) ft^sn =
    let (f^sn , t^sn) = `∙⁻¹^sn ft^sn in
    let t^SN = complete^SN t t^sn in
    case unzip f t f^sn t^SN of λ where
       (_ , c , inj₁ (v , eq , sp))        → neu (complete^SNe v sp eq ft^sn)
       (_ , c , inj₂ (_ , b , u , eq , r)) → complete^SN-β b u c r eq ft^sn

  -- ugly but it works
  unzip : ∀ {Γ σ τ i} f t → Γ ⊢sn σ ⇒ τ ∋ f < i → Γ ⊢SN σ ∋ t →
          ∃ λ α → ∃ λ (c : Γ ∣ α ⊢ τ) →
          (∃ λ v → f `∙ t ≡ cut (`var v) c × Γ ∣ α ⊢SN τ ∋ c)
        ⊎ (∃ λ β → ∃ λ (b : Term α (β ∷ Γ)) → ∃ λ u →
             f `∙ t ≡ cut (`λ b `∙ u) c
             × Γ ⊢ τ ∋ cut (`λ b `∙ u) c ↝SN cut (b [ u /0]) c)
  unzip (`var v) t v^sn  t^SN = _ , app <> t , inj₁ (v , refl , app <> t^SN)
  unzip (`λ b)   t λb^sn t^SN = _ , <> , inj₂ (_ , b , t , refl , β b t t^SN)
  unzip (f `∙ u) t fu^sn t^SN =
    let (f^sn , u^sn) = `∙⁻¹^sn fu^sn in
    let u^SN = complete^SN u u^sn in
    case unzip f u f^sn u^SN of λ where
      (_ , c , inj₁ (v , eq , sp)) →
        _ , app c t , inj₁ (v , cong (_`∙ t) eq , app sp t^SN)
      (_ , c , inj₂ (_ , b , a , eq , r)) →
        _ , app c t , inj₂ (_ , b , a , cong (_`∙ t) eq , [∙]₂ r t)


---------------------------------------------------------------------------------
-- Reducibility Candidates
---------------------------------------------------------------------------------

-- Logical Predicate
infix 3 _⊢𝓡_∋_
_⊢𝓡_∋_ : ∀ Γ σ → Term σ Γ → Set
Γ ⊢𝓡 α     ∋ t = Γ ⊢SN α ∋ t
Γ ⊢𝓡 σ ⇒ τ ∋ t = ∀ {Δ} ρ {u} → Δ ⊢𝓡 σ ∋ u → Δ ⊢𝓡 τ ∋ ren ρ t `∙ u

𝓡^P : Pred Term
pred 𝓡^P = _ ⊢𝓡 _ ∋_

-- Quote and Unquote (analogous to Normalization by Evaluation)
mutual

 quote^𝓡 : ∀ {Γ} σ {t} → Γ ⊢𝓡 σ ∋ t → Γ ⊢SN σ ∋ t
 quote^𝓡 α       t^𝓡 = t^𝓡
 quote^𝓡 (σ ⇒ τ) t^𝓡 = th⁻¹^SN _ embed refl (SN-ext z tz^SN)
   where z^𝓡  = unquote^𝓡 σ (var z)
         embed = pack s
         tz^SN = quote^𝓡 τ (t^𝓡 embed z^𝓡)

 unquote^𝓡 : ∀ {Γ} σ {t} → Γ ⊢SNe σ ∋ t → Γ ⊢𝓡 σ ∋ t
 unquote^𝓡 α       t^SNe        = neu t^SNe
 unquote^𝓡 (σ ⇒ τ) t^SNe ρ u^𝓡 = unquote^𝓡 τ (app (th^SNe ρ t^SNe) u^SN)
   where u^SN = quote^𝓡 σ u^𝓡

-- Closure of 𝓡 under Head β-Expansion
↝SN⁻¹^𝓡 : ∀ {Γ} σ {t′ t} → Γ ⊢ σ ∋ t′ ↝SN t → Γ ⊢𝓡 σ ∋ t → Γ ⊢𝓡 σ ∋ t′
↝SN⁻¹^𝓡 α       r t^𝓡 = red r t^𝓡
↝SN⁻¹^𝓡 (σ ⇒ τ) r t^𝓡 = λ ρ u^𝓡 → ↝SN⁻¹^𝓡 τ ([∙]₂ (th^↝SN ρ r) _) (t^𝓡 ρ u^𝓡)

-- Closure of 𝓡 under Thinning
th^𝓡 : ∀ {Γ Δ} σ ρ t → Γ ⊢𝓡 σ ∋ t → Δ ⊢𝓡 σ ∋ ren ρ t
th^𝓡 α       ρ t t^𝓡         = th^SN ρ t^𝓡
th^𝓡 (σ ⇒ τ) ρ t t^𝓡 ρ′ u^𝓡 = cast (t^𝓡 (select ρ ρ′) u^𝓡)
  where cast = subst (λ t → _ ⊢𝓡 _ ∋ t `∙ _) (sym $ ren² TermD t ρ ρ′)

-- Closure of 𝓡 under App
_∙^𝓡_ : ∀ {σ τ Γ f t} → Γ ⊢𝓡 σ ⇒ τ ∋ f → Γ ⊢𝓡 σ ∋ t → Γ ⊢𝓡 τ ∋ f `∙ t
f^𝓡 ∙^𝓡 t^𝓡 = cast (f^𝓡 (base vl^Var) t^𝓡)
  where cast = subst (λ t → _ ⊢𝓡 _ ∋ t `∙ _) (ren-id _)

---------------------------------------------------------------------------------
-- Proving Strong Normalization
---------------------------------------------------------------------------------

-- Fundamental lemma of 𝓡
fundamental : Fdm 𝓡^P 𝓡^P TermD Substitution
Fdm.th^P  fundamental = λ ρ v^𝓡 → th^𝓡 _ ρ _ v^𝓡
Fdm.var^P fundamental = λ x → x
Fdm.alg^P fundamental = alg^P where

  alg^P : ∀ {Γ Δ σ s} (b : ⟦ TermD ⟧ (Scope (Tm TermD s)) σ Γ) {ρ : (Γ ─Env) Term Δ} →
          let v = fmap TermD (Sem.body Substitution ρ) b in
          pred.∀[ 𝓡^P ] ρ → All TermD (Kripke^P 𝓡^P 𝓡^P) v → Δ ⊢𝓡 σ ∋ Sem.alg Substitution v
  alg^P (f `∙' t) ρ^P (f^P , t^P , _)  = f^P ∙^𝓡 t^P
  alg^P (`λ' b) {ρ₁} ρ^P (b^P , _) ρ {u} u^𝓡 = ↝SN⁻¹^𝓡 _ β-step $ cast (b^P ρ (ε^P ∙^P u^𝓡))
  -- at this point the substitution looks HORRIBLE
    where
      β-step = β (ren _ (sub _ b)) _ (quote^𝓡 _ u^𝓡)
      ρ′  = lift vl^Var (_ ∷ []) ρ
      ρ₁′ = lift vl^Tm (_ ∷ []) ρ₁

      ρ^R : rel.∀[ VarTm^R ] ρ (select (freshʳ vl^Var (_ ∷ [])) (select ρ′ (u /0])))
      lookup^R ρ^R k = sym $ begin
        lookup (base vl^Tm) (lookup (base vl^Var) (lookup ρ (lookup (base vl^Var) k)))
          ≡⟨ lookup-base^Tm _ ⟩
        `var (lookup (base vl^Var) (lookup ρ (lookup (base vl^Var) k)))
          ≡⟨ cong `var (lookup-base^Var _) ⟩
        `var (lookup ρ (lookup (base vl^Var) k))
          ≡⟨ cong (`var ∘ lookup ρ) (lookup-base^Var k) ⟩
        `var (lookup ρ k) ∎

      ρ^R′ : rel.∀[ Eq^R ] (sub (select ρ′ (u /0])) <$> ρ₁′) ((ε ∙ u) >> th^Env th^Tm ρ₁ ρ)
      lookup^R ρ^R′ z     = refl
      lookup^R ρ^R′ (s k) = begin
        sub (select ρ′ (u /0])) (ren _ (lookup ρ₁ k)) ≡⟨ rensub TermD (lookup ρ₁ k) _ _ ⟩
        sub _ (lookup ρ₁ k)                           ≡⟨ sym $ Sim.sim sim.RenSub ρ^R (lookup ρ₁ k) ⟩
        ren ρ (lookup ρ₁ k) ∎

      eq : sub ((ε ∙ u) >> th^Env th^Tm ρ₁ ρ) b ≡ ren ρ′ (sub ρ₁′ b) [ u /0]
      eq = sym $ begin
        ren ρ′ (sub ρ₁′ b) [ u /0]           ≡⟨ rensub TermD (sub ρ₁′ b) ρ′ (u /0]) ⟩
        sub (select ρ′ (u /0])) (sub ρ₁′ b)  ≡⟨ Fus.fus (Sub² TermD) ρ^R′ b ⟩
        sub ((ε ∙ u) >> th^Env th^Tm ρ₁ ρ) b ∎

      cast = subst (_ ⊢𝓡 _ ∋_) eq

-- Evaluation Function as the Corrolary of the Fundamental Lemma
eval : ∀ {Γ Δ σ ρ} → pred.∀[ 𝓡^P ] ρ → (t : Term σ Γ) → Δ ⊢𝓡 σ ∋ sub ρ t
eval = Fdm.fdm fundamental

-- Dummy Evaluation Environment to Kickstart Evaluation
dummy : ∀ {Γ} → pred.∀[ 𝓡^P ] (base vl^Tm {Γ})
lookup^P dummy v rewrite lookup-base^Tm {d = TermD} v = unquote^𝓡 _ (var v)

-- Strong Normalization as the Composition of Evaluatin in a Dummy Environment and Quote
_^SN : ∀ {Γ σ} t → Γ ⊢SN σ ∋ t
t ^SN = cast (quote^𝓡 _ (eval dummy t))
  where cast  = subst (_ ⊢SN _ ∋_) (sub-id t)

_^sn : ∀ {Γ σ} t → Γ ⊢sn σ ∋ t
t ^sn = sound^SN (t ^SN)
