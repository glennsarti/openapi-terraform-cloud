# An overview on how to release the specifications

1. Generate and merge a release prep

    * Move the Unreleased parts of the changelog to the released section

    * Modify `package.json` with the new version number

    * Modify `openapi/openapi.yaml` with the new version number

    * Run `npm run package`

2. Once merged get the commit id of the preparation

3. Tag the commit

    `git tag -a '<version>' -m '<version>' <commit id>`

    For example;
    `git tag -a '1.0.0' -m '1.0.0' 2bc51e5a5532c4c569d5206135380d26f67448c8`

4. Push the commit

    `git push <remote> <version>`

    For example;
    `git push upstream 1.0.0`

5. Checkout and reset the repo for the new tag

    For example;

    ``` powershell
    PS> git checkout 1.0.0
    PS> git reset --hard 1.0.0
    ```

6. Upload the artefacts to GitHub using the `release.ps1` PowerShell script

    For example;

    ``` powershell
    PS> .\scripts\release.ps1 -ReleaseVersion '1.0.0'
    ```
