# this file defines *and* loads one module

#> This interface for the DecisionTree package is annotated so that it
#> may serve as a template for other interfaces introducing new
#> Supervised subtypes. The annotations, which begin with "#>", should
#> be removed (but copy this file first!). See also the model
#> interface specification at "doc/adding_new_models.md".

#> Glue code goes in a module, whose name is the package name with
#> trailing underscore "_":
module DecisionTree_

#> export the new models you're going to define (and nothing else):
export DecisionTreeClassifier

#> for all Supervised models:
import MLJ

#> for all classifiers:
using CategoricalArrays

#> import package:
import DecisionTree                

# TODO: replace Float64 with type parameter

DecisionTreeClassifierFitResultType{T} =
    Tuple{Union{DecisionTree.Node{Float64,T}, DecisionTree.Leaf{T}}, MLJ.CategoricalDecoder{UInt32,T,1,UInt32}}

"""
    DecisionTreeClassifer(; kwargs...)

[https://github.com/bensadeghi/DecisionTree.jl/blob/master/README.md](https://github.com/bensadeghi/DecisionTree.jl/blob/master/README.md)

"""
mutable struct DecisionTreeClassifier{T} <: MLJ.Deterministic{DecisionTreeClassifierFitResultType{T}}
    target_type::Type{T}  # target is CategoricalArray{target_type}
    pruning_purity::Float64 
    max_depth::Int
    min_samples_leaf::Int
    min_samples_split::Int
    min_purity_increase::Float64
    n_subfeatures::Float64
    display_depth::Int
    post_prune::Bool
    merge_purity_threshold::Float64
end

# constructor:
#> all arguments are kwargs with a default value
function DecisionTreeClassifier(
    ; target_type=Int
    , pruning_purity=1.0
    , max_depth=-1
    , min_samples_leaf=1
    , min_samples_split=2
    , min_purity_increase=0.0
    , n_subfeatures=0
    , display_depth=5
    , post_prune=false
    , merge_purity_threshold=0.9)

    model = DecisionTreeClassifier{target_type}(
        target_type
        , pruning_purity
        , max_depth
        , min_samples_leaf
        , min_samples_split
        , min_purity_increase
        , n_subfeatures
        , display_depth
        , post_prune
        , merge_purity_threshold)

    message = MLJ.clean!(model)       #> future proof by including these 
    isempty(message) || @warn message #> two lines even if no clean! defined below

    return model
end

#> The following optional method (the fallback does nothing, returns
#> empty warning) is called by the constructor above but also by the
#> fit methods below:
function MLJ.clean!(model::DecisionTreeClassifier)
    warning = ""
    if  model.pruning_purity > 1
        warning *= "Need pruning_purity < 1. Resetting pruning_purity=1.0.\n"
        model.pruning_purity = 1.0
    end
    if model.min_samples_split < 2
        warning *= "Need min_samples_split < 2. Resetting min_samples_slit=2.\n"
        model.min_samples_split = 2
    end
    return warning
end

#> A required `fit` method returns `fitresult, cache, report`. (Return
#> `cache=nothing` unless you are overloading `update`)
function MLJ.fit(model::DecisionTreeClassifier{T2}
             , verbosity   #> must be here even if unsupported in pkg (as here)
             , X::Matrix{Float64}
             , y::CategoricalVector{T}) where {T,T2}

    T == T2 || throw(ErrorException("Type, $T, of target incompatible "*
                                    "with type, $T2, of $model."))

    decoder = MLJ.CategoricalDecoder(y)
    y_plain = MLJ.transform(decoder, y)
    
    tree = DecisionTree.build_tree(y_plain
                                   , X
                                   , model.n_subfeatures
                                   , model.max_depth
                                   , model.min_samples_leaf
                                   , model.min_samples_split
                                   , model.min_purity_increase)
    if model.post_prune 
        tree = DecisionTree.prune_tree(tree, model.merge_purity_threshold)
    end
    
    verbosity < 3 || DecisionTree.print_tree(tree, model.display_depth)

    fitresult = (tree, decoder)

    #> return package-specific statistics (eg, feature rankings,
    #> internal estimates of generalization error) in `report`, which
    #> should be `nothing` or a dictionary keyed on symbols.
        
    cache = nothing
    report = nothing
    
    return fitresult, cache, report 

end

#> method to coerce generic data into form required by fit:
MLJ.coerce(model::DecisionTreeClassifier, Xtable) = MLJ.matrix(Xtable)

function MLJ.predict(model::DecisionTreeClassifier{T} 
                     , fitresult
                     , Xnew) where T
    tree, decoder = fitresult
    return MLJ.inverse_transform(decoder, DecisionTree.apply_tree(tree, Xnew))
end

# metadata:
function MLJ.info(::Type{DecisionTreeClassifier})
    d = Dict{String,String}()
    d["package name"] = "DecisionTree"
    d["package uuid"] = "7806a523-6efd-50cb-b5f6-3fa6f1930dbb"
    d["properties"] = []
    d["operations"] = ["predict",]
    d["inputs_can_be"] = ["numeric",]
    d["outputs_are"] = ["nominal", "multiclass", "deterministic", "univariate"]
    return d
end

end # module


## EXPOSE THE INTERFACE

using .DecisionTree_
export DecisionTreeClassifier         

