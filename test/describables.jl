using Describables: Describables, @describable, show_describable

# Workflow #1: `@describable struct Foo ... end`
@describable struct Foo
    x::Float64
    y::AbstractString
    z::Any
end

# Workflow #2: `@describable Bar`
struct Bar
    x::Float64
    y::AbstractString
    z::Any
end
@describable Bar

# Workflow #3 (the macro-less workflow): just manually define the `Base.show` method.
struct Baz
    x::Float64
    y::AbstractString
    z::Any
end
Base.show(io::Base.IO, mime::Base.MIME"text/plain", obj::Baz) = show_describable(io, mime, obj)

# And this struct is never made describable
struct IAmNotDescribable
    x::Float64
    y::AbstractString
    z::Any
end

@testset "show" begin
    @testset for T in [Foo, Bar, Baz]
        mimetype = Base.MIME"text/plain"
        mime = mimetype()

        obj1 = T(1.0, "two", 3)
        obj4 = T(4.0, "five", 6)
        obj7 = T(7.0, "eight", 9)

        obj_IAmNotDescribable = IAmNotDescribable(10.0, "eleven", 12)

        my_test_closure_1_A = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj1)
            actual_str = String(take!(io))
            expected_str = "$(T)(1.0, \"two\", 3, #=  =#)"
            @test actual_str == expected_str
        end
        my_test_closure_1_B = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj1)
            actual_str = String(take!(io))
            expected_str = "$(T)(1.0, \"two\", 3, #= this is my description for obj1 =#)"
            @test actual_str == expected_str
        end
        my_test_closure_1_C = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj1)
            actual_str = String(take!(io))
            expected_str = "$(T)(1.0, \"two\", 3, #= obj1 has a new description =#)"
            @test actual_str == expected_str
        end

        my_test_closure_4_A = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj4)
            actual_str = String(take!(io))
            expected_str = "$(T)(4.0, \"five\", 6, #=  =#)"
            @test actual_str == expected_str
        end
        my_test_closure_4_B = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj4)
            actual_str = String(take!(io))
            expected_str = "$(T)(4.0, \"five\", 6, #= we give obj4 a different description =#)"
            @test actual_str == expected_str
        end

        my_test_closure_7 = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj7)
            actual_str = String(take!(io))
            expected_str = "$(T)(7.0, \"eight\", 9, #=  =#)"
            @test actual_str == expected_str
        end

        my_test_closure_IAmNotDescribable = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj_IAmNotDescribable)
            actual_str = String(take!(io))
            expected_str = "IAmNotDescribable(10.0, \"eleven\", 12)"
            @test actual_str == expected_str
        end

        my_test_closure_1_A()
        my_test_closure_4_A()
        my_test_closure_7()
        my_test_closure_IAmNotDescribable()


        Describables.set_description!(obj1, "this is my description for obj1")
        # We intentionally do not set a description for obj4 or obj7.
        my_test_closure_1_B()
        my_test_closure_4_A()
        my_test_closure_7()
        my_test_closure_IAmNotDescribable()

        # Descriptions can be changed.
        Describables.set_description!(obj1, "obj1 has a new description")
        my_test_closure_1_C()
        my_test_closure_4_A()
        my_test_closure_7()
        my_test_closure_IAmNotDescribable()

        # `set_description!` should be idempotent.
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        my_test_closure_1_C()
        my_test_closure_4_A()
        my_test_closure_7()
        my_test_closure_IAmNotDescribable()

        # When we set a description for obj4, the description for obj1 is
        # unmodified
        Describables.set_description!(obj4, "we give obj4 a different description")
        my_test_closure_1_C()
        my_test_closure_4_B()
        my_test_closure_7()
        my_test_closure_IAmNotDescribable()

        @testset "code coverage" begin
            @testset "get_description" begin
                @test Describables.get_description(obj1) == "obj1 has a new description"
            end
        end
    end
end

# @testset "type stability" begin
# end
