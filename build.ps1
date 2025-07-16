Param(
    [string]$Task
)

if (-not (Test-Path "bin")) {
    mkdir .\bin, .\bin\Debug, .\bin\Release
}

switch ($Task.ToLower()) {
    "debug" {
        odin build src -out:bin\Debug\rltut.exe -debug
    }
    "release" {
        odin build src -out:bin\Release\rltut.exe
    }
    "clean" {
        Remove-Item -Recurse bin
    }
    default {
        "Usage: .\build.ps1 (debug|release|clean)"
    }
}

