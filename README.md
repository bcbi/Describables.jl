# Describables.jl

[![Continuous integration (CI)](https://github.com/bcbi/Describables.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/bcbi/Describables.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/bcbi/Describables.jl/graph/badge.svg?token=3GpnCnTyFz)](https://codecov.io/gh/bcbi/Describables.jl)

## Installation

```julia
julia> import Pkg

julia> Pkg.add(url = "https://github.com/bcbi/Describables.jl")
```

## Usage

### Option 1: `@describable struct Foo ... end`

```julia
julia> using Describables: Describables, @describable, set_description!

julia> @describable struct Foo
           x
           y
       end

julia> Foo(1, 2)
Foo(1, 2, #=  =#)

julia> set_description!(Foo(1, 2), "my description")

julia> Foo(1, 2)
Foo(1, 2, #= my description =#)
```

### Option 2: `@describable Bar`

```julia
julia> using Describables: Describables, @describable, set_description!

julia> struct Bar
           x
           y
       end

julia> @describable Bar

julia> Bar(1, 2)
Bar(1, 2, #=  =#)

julia> set_description!(Bar(1, 2), "my description")

julia> Bar(1, 2)
Bar(1, 2, #= my description =#)
```

```julia
julia> Base.@kwdef struct Baz
           x
           y
       end
Baz

julia> @describable Baz

julia> Baz(; x = 1, y = 2)
Baz(1, 2, #=  =#)

julia> set_description!(Baz(; x = 1, y = 2), "my description")

julia> Baz(; x = 1, y = 2)
Baz(1, 2, #= my description =#)
```

### Option 3: Macro-less workflow (manually define the `Base.show` method)

```julia
julia> using Describables: Describables, show_describable, set_description!

julia> struct Hello
           x
           y
       end

julia> Base.show(io::IO, mime::MIME"text/plain", obj::Hello) = show_describable(io, mime, obj)

julia> Hello(1, 2)
Hello(1, 2, #=  =#)

julia> set_description!(Hello(1, 2), "my description")

julia> Hello(1, 2)

julia> Hello(1, 2)
Hello(1, 2, #= my description =#)
```
