module Describables

export get_description
export set_description!
export @describable
export show_describable

### Lockables

# No need for `@static` at the top-level:
@static if Base.VERSION >= v"1.2-"
    # `Base.AbstractLock` was only introduced in Julia 1.2
    const _ABSTRACT_LOCK_TYPE = Base.AbstractLock
else
    const _ABSTRACT_LOCK_TYPE = Any
end
struct Lockable{T, L <: _ABSTRACT_LOCK_TYPE}
    value::T
    lock::L
end
Lockable(value) = Lockable(value, Base.ReentrantLock())

function mylock(f::F, l::Lockable{T, L}) where {F, T, L}
    Base.lock(l.lock::L) do
        f(l.value::T)
    end
end

### Describables

struct LockedDescriptionCache
    l::Lockable{Dict{Any, String}, Base.ReentrantLock}
end
LockedDescriptionCache() = LockedDescriptionCache(Lockable(Dict{Any, String}()))

const DEFAULT_CACHE = Ref{LockedDescriptionCache}()

function __init__()
    DEFAULT_CACHE[] = LockedDescriptionCache()
    return nothing
end

function get_default_cache()
    return DEFAULT_CACHE[]
end

get_description(obj::Any) = get_description(get_default_cache(), obj)
function get_description(cache::LockedDescriptionCache, obj::Any)
    descr = mylock(cache.l) do dict
        get(dict, obj, nothing)
    end
    return descr
end

set_description!(obj::Any, new_descr::AbstractString) = set_description!(get_default_cache(), obj, new_descr)
function set_description!(cache::LockedDescriptionCache, obj::Any, new_descr::AbstractString)
    new_descr_clean = convert(String, strip(new_descr))::String
    if !isempty(new_descr_clean)
        mylock(cache.l) do dict
            dict[obj] = new_descr_clean
        end
    end
    return nothing
end

show_describable(io::IO, mime::Base.MIME"text/plain", obj::T) where {T} = show_describable(get_default_cache(), io, mime, obj)
function show_describable(cache, io::IO, mime::Base.MIME"text/plain", obj::T) where {T}
    print(io, T)
    print(io, "(")
    for field in fieldnames(T)
        value = getfield(obj, field)
        representable_value = repr(value)
        print(io, representable_value)
        print(io, ", ")
    end
    print(io, "#= ")
    descr = get_description(cache, obj)
    if descr !== nothing
        print(io, descr)
    end
    print(io, " =#")
    print(io, ")")
    return nothing
end

function _base_show_method_expr(Tname::Symbol)
    result = quote
        function Base.show(io::Base.IO, mime::Base.MIME"text/plain", obj::$(esc(Tname)))
            Describables.show_describable(io, mime, obj)
            return nothing
        end
        # Do we also need to define `Base.print`? No. The Julia manual says:
        # > print falls back to calling show, so most types should just define show.
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/strings/io.jl#L5-L31
        #
        # Do we also need to define `Base.repr`? No. If I understand correctly,
        # if we don't define any methods of `Base.repr`, then `Base.repr` will
        # automatically fall back to calling the three-argument `Base.show(io, mime, obj)`
        # method that we defined above.
        # The Julia manual says the following about the `Base.repr(mime, x; context=nothing)` method:
        # > Return an AbstractString or Vector{UInt8} containing the representation of x in the
        # > requested mime type, as written by show(io, mime, x) (throwing a MethodError if no
        # > appropriate show is available).
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/multimedia.jl#L125-L158
    end
    return result
end

_describable_macro(Tname::Symbol) = _base_show_method_expr(Tname)
function _describable_macro(original_ex::Expr)
    if original_ex.head != :struct
        msg = "Argument must be either a struct definition or a symbol"
        throw(ArgumentError(msg))
    end
    struct_name = original_ex.args[2]::Symbol
    show_method_expr = _base_show_method_expr(struct_name)
    result = quote
        $(original_ex)
        $(show_method_expr)
    end
    return result
end
macro describable(ex::Union{Expr, Symbol})
    return _describable_macro(ex)
end

end # module
