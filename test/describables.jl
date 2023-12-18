struct Foo
    x::Float64
    y::AbstractString
    z::Any
end
Describables.@describable Foo

# Describables.@describable struct Bar # TODO: uncomment this line
struct Bar # TODO: delete this line
    x::Float64
    y::AbstractString
    z::Any
end
Describables.@describable Bar # TODO: delete this line

struct INeverGetDescribed
    x::Float64
    y::AbstractString
    z::Any
end

@testset "show" begin
    @testset for T in [Foo, Bar]
        mimetype = Base.MIME"text/plain"
        mime = mimetype()

        obj1 = T(1.0, "two", 3)
        obj4 = T(4.0, "five", 6)

        obj_INeverGetDescribed = INeverGetDescribed(7.0, "eight", 9)

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

        my_test_closure_4 = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj4)
            actual_str = String(take!(io))
            expected_str = "$(T)(4.0, \"five\", 6, #=  =#)"
            @test actual_str == expected_str
        end

        my_test_closure_INeverGetDescribed = () -> begin
            io = IOBuffer()
            Base.show(io, mime, obj_INeverGetDescribed)
            actual_str = String(take!(io))
            expected_str = "INeverGetDescribed(7.0, \"eight\", 9)"
            @test actual_str == expected_str
        end

        my_test_closure_1_A()
        my_test_closure_4()
        my_test_closure_INeverGetDescribed()


        Describables.set_description!(obj1, "this is my description for obj1")
        # We intentionally do not set a description for obj4.
        my_test_closure_1_B()
        my_test_closure_4()
        my_test_closure_INeverGetDescribed()

        # Descriptions can be changed.
        Describables.set_description!(obj1, "obj1 has a new description")

        my_test_closure_1_C()
        my_test_closure_4()
        my_test_closure_INeverGetDescribed()

        # `set_description!` should be idempotent.
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")
        Describables.set_description!(obj1, "obj1 has a new description")

        my_test_closure_1_C()
        my_test_closure_4()
        my_test_closure_INeverGetDescribed()

        @testset "code coverage" begin
            @testset "get_description" begin
                @test Describables.get_description(obj1) == "obj1 has a new description"
            end
        end
    end
end

# @testset "type stability" begin
# end
