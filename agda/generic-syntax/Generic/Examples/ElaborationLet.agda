module Generic.Examples.ElaborationLet where

open import Size
open import Data.Bool
open import Data.Product
open import Data.List.All
open import Data.List.Base hiding ([_])
open import Function.Base
open import Relation.Binary.PropositionalEquality hiding ([_])

open import indexed
open import var
open import varlike
open import environment
open import Generic.Syntax
open import Generic.Semantics

module _ {I : Set} where

 Let : Desc I
 Let = `σ (List I) $ λ Δ → `σ I $ λ i → `Xs Δ (`X Δ i (`∎ i))

module _ {I : Set} {d : Desc I} where

 UnLet : Sem (Let `+ d) (Tm d ∞) (Tm d ∞)
 Sem.th^𝓥  UnLet = th^Tm
 Sem.var   UnLet = id
 Sem.alg   UnLet =
   case alg' (Sem.alg Substitution)

  where

  Val : ∀ d → List I → I → List I → Set
  Val d = Kripke (Tm d ∞) (Tm d ∞)

  env : {d : Desc I} (Δ : List I) → [ (λ Γ → All (λ i → Val d [] i Γ) Δ) ⟶ (Δ ─Env) (Val d []) ]
  env []       vs        = ε
  env (σ ∷ Δ)  (v ∷ vs)  = env Δ vs ∙ v

  apply : {d : Desc I} (Δ : List I) {i : I} →
          [ Val d Δ i ⟶ (λ Γ → All (λ i → Val d [] i Γ) Δ) ⟶ Tm d ∞ i ]
  apply []        b vs = b
  apply Δ@(_ ∷ _) b vs = b (base vl^Var) (env Δ vs)

  alg' : {d : Desc I} {i : I} → [ ⟦ Let ⟧ (Val d) i ⟶ Tm d ∞ i ]
  alg' (Δ , i , t) = let (es , b , eq) = unXs Δ t
                     in subst (λ i → Tm _ ∞ i _) (sym eq) (apply Δ b es)


 unlet : {i : I} → [ Tm (Let `+ d) ∞ i ⟶ Tm d ∞ i ]
 unlet = Sem.sem UnLet (pack `var)
