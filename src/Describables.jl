module Describables

export get_description
export set_description!
export @describable

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

# TODO: narrow the type restriction on `mime`:
show_describable(io::IO, mime, obj::T) where {T} = show_describable(get_default_cache(), io, mime, obj)
# TODO: narrow the type restriction on `mime`:
function show_describable(cache, io::IO, mime, obj::T) where {T}
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

function _describable_macro(T::Symbol)
    result = quote
        function Base.show(io::Base.IO, mime::Base.MIME"text/plain", obj::$(esc(T)))
            Describables.show_describable(io, mime, obj)
            return nothing
        end
    end
    return result
end

macro describable(ex::Symbol)
    return _describable_macro(ex)
end

end # module
