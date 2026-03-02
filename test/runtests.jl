using Test
using Logging: Warn
import Pkg
using MWEHelper

include("mwe.jl")

@testset "MWEHelper" begin
    @testset "bug_report mwe1" begin
        tmpfile = tempname() * ".md"
        @test_logs min_level = Warn bug_report("test mwe1", mwe1; filename = tmpfile)
        report = read(tmpfile, String)
        rm(tmpfile)

        # Correct packages detected
        @test occursin("using ModelingToolkitBase", report)

        # Aliases detected
        @test occursin("t_nounits as t", report)
        @test occursin("D_nounits as D", report)

        # Helper functions included
        @test occursin("function create_sys", report)
        @test occursin("function get_eqs", report)

        # No duplicates
        @test count("function create_sys", report) == 1
        @test count("function get_eqs", report) == 1

        # MWE source and call included
        @test occursin("function mwe1", report)
        @test occursin("mwe1()", report)
    end

    @testset "bug_report mwe2" begin
        tmpfile = tempname() * ".md"
        @test_logs min_level = Warn bug_report("test mwe2", mwe2; filename = tmpfile)
        report = read(tmpfile, String)
        rm(tmpfile)

        # Correct packages detected
        @test occursin("using ModelingToolkitBase", report)

        # Aliases detected
        @test occursin("t_nounits as t", report)
        @test occursin("D_nounits as D", report)

        # Helper functions included, no duplicates
        @test occursin("function create_sys", report)
        @test occursin("function get_eqs", report)
        @test count("function create_sys", report) == 1
        @test count("function get_eqs", report) == 1

        # MWE source and call included
        @test occursin("function mwe2", report)
        @test occursin("mwe2()", report)
    end

    @testset "bug_report mwe3" begin
        tmpfile = tempname() * ".md"
        @test_logs min_level = Warn bug_report("test mwe3", mwe3; filename = tmpfile)
        report = read(tmpfile, String)
        rm(tmpfile)

        # Global binding detected
        @test occursin("_name = :foo", report)

        # Aliases detected
        @test occursin("t_nounits as t", report)
        @test occursin("D_nounits as D", report)

        # Helper functions included, no duplicates
        @test occursin("function create_sys", report)
        @test occursin("function get_eqs", report)
        @test count("function create_sys", report) == 1
        @test count("function get_eqs", report) == 1

        # MWE source and call included
        @test occursin("function mwe3", report)
        @test occursin("mwe3()", report)
    end

    @testset "bug_report with repo-tracked package" begin
        test_env = mktempdir()
        original_project = Base.active_project()
        try
            Pkg.activate(test_env; io = devnull)
            Pkg.add(Pkg.PackageSpec(url = "https://github.com/JuliaLang/Example.jl", rev = "master"); io = devnull)
            @eval using Example

            mwe_file = tempname() * ".jl"
            write(mwe_file, """
            function mwe_repo_tracked()
                Example.hello("world")
                error("repo tracked test")
            end
            """)
            include(mwe_file)

            tmpfile = tempname() * ".md"
            @test_logs min_level = Warn bug_report("test repo tracking", mwe_repo_tracked; filename = tmpfile)
            report = read(tmpfile, String)
            rm(tmpfile)

            @test occursin("using Example", report)
            @test occursin("function mwe_repo_tracked", report)
            @test occursin("mwe_repo_tracked()", report)
            # Verify the report shows the URL tracking
            @test occursin("Example.jl#master", report)
        finally
            Pkg.activate(original_project; io = devnull)
        end
    end

    @testset "bug_report with dev'd package" begin
        test_env = mktempdir()
        example_dir = mktempdir()
        original_project = Base.active_project()
        try
            run(pipeline(`git clone https://github.com/JuliaLang/Example.jl $example_dir`, stdout = devnull, stderr = devnull))
            Pkg.activate(test_env; io = devnull)
            Pkg.develop(Pkg.PackageSpec(path = example_dir); io = devnull)

            mwe_file = tempname() * ".jl"
            write(mwe_file, """
            function mwe_dev()
                Example.hello("world")
                error("dev test")
            end
            """)
            include(mwe_file)

            tmpfile = tempname() * ".md"
            @test_logs (:warn, r"dev'd") min_level = Warn bug_report("test dev tracking", mwe_dev; filename = tmpfile)
            report = read(tmpfile, String)
            rm(tmpfile)

            @test occursin("using Example", report)
            @test occursin("function mwe_dev", report)
            @test occursin("mwe_dev()", report)
            # Verify the report shows the dev path
            @test occursin(example_dir, report)
        finally
            Pkg.activate(original_project; io = devnull)
        end
    end
end
