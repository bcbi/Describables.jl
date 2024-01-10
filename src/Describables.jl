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
struct Lockable{T,L<:_ABSTRACT_LOCK_TYPE}
    value::T
    lock::L
end
Lockable(value) = Lockable(value, Base.ReentrantLock())

function mylock(f::F, l::Lockable{T,L}) where {F,T,L}
    Base.lock(l.lock::L) do
        f(l.value::T)
    end
end

### Describables

struct LockedDescriptionCache
    l::Lockable{Dict{Any,String},Base.ReentrantLock}
end
LockedDescriptionCache() = LockedDescriptionCache(Lockable(Dict{Any,String}()))

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

set_description!(obj::Any, new_descr::AbstractString) =
    set_description!(get_default_cache(), obj, new_descr)
function set_description!(
    cache::LockedDescriptionCache,
    obj::Any,
    new_descr::AbstractString,
)
    new_descr_clean = convert(String, strip(new_descr))::String
    if !isempty(new_descr_clean)
        mylock(cache.l) do dict
            dict[obj] = new_descr_clean
        end
    end
    return nothing
end

# Two-argument method, analogous to the two-argument `Base.show`:
function show_describable(io::IO, obj::T) where {T}
    mime = Base.MIME"text/plain"()
    show_describable(io, mime, obj)
    return nothing
end

# Three-argument method, analogous to the three-argument `Base.show`:
function show_describable(io::IO, mime::Base.MIME"text/plain", obj::T) where {T}
    cache = get_default_cache()
    show_describable_from_cache(cache, io, mime, obj)
    return nothing
end

# function show_describable_from_cache(
#         cache::LockedDescriptionCache,
#         io::IO,
#         obj::T,
#     ) where {T}
#     msg = """
#         This method is not implemented. You need to manually specify
#         a value for all four arguments, including the `mime` argument.
#     """
#     error(msg)
# end

function show_describable_from_cache(
    cache::LockedDescriptionCache,
    io::IO,
    mime::Base.MIME"text/plain",
    obj::T,
) where {T}
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
        # Two-argument `Base.show` method.
        # The Julia manual says:
        # > Write a text representation of a value x to the output stream io.
        # > New types T should overload show(io::IO, x::T).
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/show.jl#L430-L456
        function Base.show(io::Base.IO, obj::$(esc(Tname)))
            # The user (i.e. the person that is calling the `@describable` macro)
            # needs to have brought the `Describable` name into scope. So they
            # need to have done `import Describable` or something similar.
            #
            # It's not sufficient to only do `using Describable: @describable`,
            # because this doesn't bring the `Describable` name into scope. So you
            # need to do either `using Describable: Describable, @describable` or
            # `import Describable; using Describable: @describable` or something
            # along those lines.
            #
            # Note: please do not do `using Describable`.
            # See https://github.com/JuliaLang/julia/pull/42080 for more details.
            Describables.show_describable(io, obj)
            return nothing
        end

        # Do we also need to define a three-argument `Base.show` method, i.e.
        # `Base.show(io, mime, obj::T)`? No. If I understand correctly,
        # if we don't define the three-argument `Base.show` method, then calling
        # the three-argument `Base.show` will automatically fall back to calling
        # the two-argument `Base.show` method that we defined above.
        # As supporting evidence, the Julia manual says:
        # > The default MIME type is MIME"text/plain". There is a fallback definition
        # > for text/plain output that calls show with 2 arguments, so it is not always
        # > necessary to add a method for that case.
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/multimedia.jl#L79-L121
        # function Base.show(io::Base.IO, mime::Base.MIME"text/plain", obj::$(esc(Tname)))
        #     Describables.show_describable(io, mime, obj)
        #     return nothing
        # end

        # Do we also need to define `Base.print`? No. The Julia manual says:
        # > print falls back to calling show, so most types should just define show.
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/strings/io.jl#L5-L31

        # Do we also need to define `Base.repr`? No. If I understand correctly,
        # if we don't define any methods of `Base.repr`, then `Base.repr` will
        # automatically fall back to calling the three-argument `Base.show(io, mime, obj)`
        # method, which in turn will automatically fall back to calling the
        # two-argument `Base.show(io, obj)`, as described in the comment above.
        # The Julia manual says the following about the `Base.repr(mime, x; context=nothing)` method:
        # > Return an AbstractString or Vector{UInt8} containing the representation of x in the
        # > requested mime type, as written by show(io, mime, x) (throwing a MethodError if no
        # > appropriate show is available).
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/multimedia.jl#L125-L158

        # Do we also need to define `Base.display`?. No. The Julia manual says:
        # > The display functions ultimately call show in order to write an object x as a given
        # mime type to a given I/O stream io (usually a memory buffer), if possible.
        # Source: https://github.com/JuliaLang/julia/blob/3120989f39bb7ef7863c4aab8ab1227cf71eec66/base/multimedia.jl#L79-L121
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
macro describable(ex::Union{Expr,Symbol})
    return _describable_macro(ex)
end

end # module
