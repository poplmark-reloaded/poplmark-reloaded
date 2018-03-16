module Generic.Identity where

open import Size
open import Agda.Builtin.List
open import Data.Product hiding (zip)
open import Data.Sum
open import var
open import rel
open import varlike
open import environment
open import Generic.Syntax
open import Generic.Semantics
open import Generic.Zip
open import Generic.Simulation

open import Function
open import Relation.Binary.PropositionalEquality as PEq
open ≡-Reasoning

module _ {I : Set} {d : Desc I} where

 data _≅_ {σ : I} {Γ : List I} : {s : Size} → Tm d s σ Γ → {t : Size} → Tm d t σ Γ → Set
 ⟨_⟩_≅_ : (e : Desc I) {σ : I} {Γ : List I} {s : Size} → ⟦ e ⟧ (Scope (Tm d s)) σ Γ → {t : Size} → ⟦ e ⟧ (Scope (Tm d t)) σ Γ → Set

 data _≅_ {σ} {Γ} where
   `var : {s t : Size} {k l : Var σ Γ} → k ≡ l → `var {s = s} k ≅ `var {s = t} l
   `con : {s t : Size} {b : ⟦ d ⟧ (Scope (Tm d s)) σ Γ} {c : ⟦ d ⟧ (Scope (Tm d t)) σ Γ} →
          ⟨ d ⟩ b ≅ c → `con {s = s} b ≅ `con {s = t} c

 ⟨ e ⟩ b ≅ c = Zip e (λ _ _  t u → t ≅ u) b c

 ≅⇒≡   : ∀ {σ Γ} {t u : Tm d ∞ σ Γ} → t ≅ u → t ≡ u
 ⟨_⟩≅⇒≡ : ∀ {σ Γ} e {t u : ⟦ e ⟧ (Scope (Tm d ∞)) σ Γ} → ⟨ e ⟩ t ≅ u → t ≡ u

 ≅⇒≡ (`var eq) = cong `var eq
 ≅⇒≡ (`con eq) = cong `con (⟨ d ⟩≅⇒≡ eq)

 ⟨ `σ A d   ⟩≅⇒≡ (refl , eq) = cong ,_ (⟨ d _ ⟩≅⇒≡ eq)
 ⟨ `X Δ j d ⟩≅⇒≡ (≅-pr , eq) = cong₂ _,_ (≅⇒≡ ≅-pr) (⟨ d ⟩≅⇒≡ eq)
 ⟨ `∎ i     ⟩≅⇒≡ eq          = proof-irrelevance _ _

module RenId {I : Set} {d : Desc I} where

 ren-id      : ∀ {s : Size} {i Γ} (t : Tm d s i Γ) {ρ : Thinning Γ Γ} → ∀[ Eq^R ] ρ (base vl^Var) → ren ρ t ≅ t
 ren-body-id : ∀ Δ i {Γ s} (t : Scope (Tm d s) Δ i Γ) {ρ : Thinning Γ Γ} → ∀[ Eq^R ] ρ (base vl^Var) → reify vl^Var Δ i (Sem.body Renaming ρ Δ i t) ≅ t

 ren-id (`var k) ρ^R = `var (trans (lookup^R ρ^R k) (lookup-base^Var k))
 ren-id (`con t) ρ^R = `con (subst₂ (⟨ d ⟩_≅_) (sym $ fmap² d (Sem.body Renaming _) (reify vl^Var) _) (fmap-id d _)
                            $ zip d (λ Δ i t → ren-body-id Δ i t ρ^R) _)

 ren-body-id []        i t     = ren-id t
 ren-body-id Δ@(_ ∷ _) i {Γ} t {ρ} ρ^R = ren-id t eq^R where

  eq^R : ∀[ Eq^R ] (lift vl^Var Δ ρ) (base vl^Var)
  lookup^R eq^R k with split Δ k | inspect (split Δ) k
  ... | inj₁ k₁ | PEq.[ eq ] = begin
    injectˡ Γ (lookup (base vl^Var) k₁) ≡⟨ cong (injectˡ Γ) (lookup-base^Var k₁) ⟩
    injectˡ Γ k₁                        ≡⟨ injectˡ-split Δ k eq ⟩
    k                                   ≡⟨ sym (lookup-base^Var k) ⟩
    lookup (base vl^Var) k              ∎
  ... | inj₂ k₂ | PEq.[ eq ] = begin
    injectʳ Δ (lookup (base vl^Var) (lookup ρ k₂)) ≡⟨ cong (injectʳ Δ) (lookup-base^Var _) ⟩
    injectʳ Δ (lookup ρ k₂)                        ≡⟨ cong (injectʳ Δ) (lookup^R ρ^R k₂) ⟩
    injectʳ Δ (lookup (base vl^Var) k₂)            ≡⟨ cong (injectʳ Δ) (lookup-base^Var k₂) ⟩
    injectʳ Δ k₂                                   ≡⟨ injectʳ-split Δ k eq ⟩
    k                                              ≡⟨ sym (lookup-base^Var k) ⟩
    lookup (base vl^Var) k                         ∎

module _ {I : Set} {d : Desc I} where

  ren-id : ∀ {σ Γ} (t : Tm d ∞ σ Γ) → ren (base vl^Var) t ≡ t
  ren-id t = ≅⇒≡ (RenId.ren-id t (pack^R λ _ → refl))

  sub-id : ∀ {σ Γ} (t : Tm d ∞ σ Γ) → sub (base vl^Tm) t ≡ t
  sub-id t = begin
    sub (base vl^Tm) t  ≡⟨ sym $ Sim.sim RenSub base^VarTm^R t ⟩
    ren (base vl^Var) t ≡⟨ ren-id t ⟩
    t                   ∎
