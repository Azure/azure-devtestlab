# Tests description
The tests are in two groups:

1. `Fast-*.tests.ps1`: they run using an existing Lab Account and Lab
2. others: they create new Lab Accounts, Labs and VMs

The `Fast` tests need to be either idempotent or additive. Aka, they need to run in parallel without interfering with each other, as they are using the same resources. I.E. Adding users to the lab and then check that *just* the users that you added are present. This is tricky to do, so be careful.

The other tests achive the same result by creating randomly named Lab Accounts in the RG for the tests . But they are, obviously much slower (in total about 1hr at the time of writing this).

Try to add to the Fast tests if you can, but it is not always possible.

The tests run every day and whenever there is a new Push/PR in the library directory or workflows directory.

A `Cleanup.ps1` runs every N days to remove the randomly named Lab Accounts. I try to do it in the tests, but it is hard to predict all possible failure mode. 

The tests run a Github actions on Windows and Linux latest, using the latest Az module. If you run them locally, make sure to use the same version of Pester as the Github actions.

On Azure, the service principal that runs the test is `luca-azlabtest` and the RG containing all the resrouces is `azlabslibrary`.

## To do

1. Pester runs with a `RequiredVersion` because I didn't have the energy to fix the random errors I was getting when moving it to the latest (breaking) version.