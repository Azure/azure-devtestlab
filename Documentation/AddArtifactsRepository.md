# Add a Git Artifact Repository to Your DevTest Lab

By default, a DevTest Lab includes artifacts from the official Azure DevTest
Lab artifact repository. You can add a Git artifact repository (repo) to your
lab to include the artifacts that your team creates. The repository can be 
hosted on [Github](https://www.github.com/) or on [Visual Studio Team 
Services (VS Team Services)](https://visualstudio.com/).

- To learn how to create a Github repository, see [Github 
  Bootcamp](https://help.github.com/categories/bootcamp/).
- To learn how to create a VSO project with a Git Repository, see [Set up 
  Visual Studio](https://www.visualstudio.com/get-started/setup/set-up-vs).

The repository must contain a top level folder with subfolders corresponding
to each Artifacts. Each Artifact subfolder must contain an artifact definition
file (Artifactfile.json) and any other optional script files related to the 
Artifact.

Here's how a repo might look in Github:

![Depiction of artifacts folder in Github][artifact-repo-github]

## Adding a Github Artifacts Repository to Your Lab

To add a Github artifacts repository to your lab, you first get the HTTPS clone
url and Personal Access Token from the artifacts repo, then you enter that 
information in your lab 

### In the Github artifacts repository

1. On the home page of the Github repo that contains the team artifacts, copy
   and then save the HTTPS clone url. For example, you can save the url to a
   temporary Notepad file

   ![Image of the clone widget on Github][github-clone]
   
2. On the home page of the Github repo:

3. Open the user menu in the upper-right corner.

4. Choose the **Settings** item.

   ![Github 'Settings' menu screen-capture][github-settings-item]

5. In the Personal Settings list on the Your Profile page, choose Personal
   access tokens.

6. On the Personal access tokens page, choose Generate new token.

7. On the New personal access token page, enter a Token description, accept
   the default items in the Select scopes, and then choose Generate Token.

8. On the Personal access tokens page, copy and then save the generated
   token:
   
   ![Github 'personal access tokens' UI screencap][github-pat]
   
### In the DevTest Lab

1. On the home blade of your lab, choose Settings

   ![Azure DevTest Lab settings button][azure-devtest-lab-settings]

2. On the Settings blade, choose Artifacts Repository

3. On the Artifacts Repository blade
   1. Enter a display Name for the repo.

   2. Enter the saved Git Clone Url.

   3. Enter the relative Folder Path of the top level folder  that contains the artifacts.

   4. Enter the saved Personal Access Token to the artifacts repo.

   5. Choose Save.

      ![Azure DevTest Lab repository settings screen cap][azure-artifact-repo-settings]

   The artifacts in your repository are now listed on the **Add Artifacts**
   blade.

## Adding a Visual Studio Git artifact repository to your lab

To add a Visual Studio Git artifact repository to your lab, you first get the
HTTPS clone url and Personal Access Token from the artifacts repo, then you
enter that information in your lab.

On the Visual Studio web page of your artifact project

1. Open the home page of your team collection (for example, 
   https://contoso-web-team.visualstudio.com), and then choose the artifact
   project.

   ![Choose your VS Team Services home page][vsts-choose-team]

2. On the project home page, choose the Code link.

   ![Choose the 'CODE' tab in VS Team Services][code-tab-vsts]

3. To view the clone url, on the project Code page, choose the Clone link.

   ![Click on the 'Clone' button in the VS Team Services CODE UI][vsts-clone-button]

4. Copy and save the url that's displayed. For example, save it to a temporary
   Notepad file.

   ![Copy/Paste the URI to clone the Git repo with][vsts-clone-uri]
   
5. To create a Personal Access Token, choose My profile from the user account
   drop-down menu.
   
   ![VS Team Services profile User Account menu][vsts-profile-menu]
   
6. On the profile information page choose the Security tab.

   ![VS Team Services security tab][vsts-security-tab]
   
7. On the **Security** tab,choose the **Add** link.
 
   ![VS Team Services add PAT menu][vsts-security-pat-add]
   
8. In Create a personal access token
   1. Enter a Description for the token.
   2. Select 180 days from the Expires In list.
   3. Choose All accessible accounts from the Accounts list.
   4. Choose the All scopes option.
   5. Choose Create Token
   
   ![Create your Personal Access Token UI][vsts-create-pat]
   
9. The new token appears in the **Personal Access Tokens** list. Choose the
   **Copy Token** and then save the token value.
   
   ![Copy your personal access token to the clipboard (button)][vsts-copy-token]
   
## In the DevTest Lab

1. On the home blade of your lab, choose Settings

   ![The 'Settings' button for your Azure DevTest Lab][azure-devtest-lab-settings-button]
   
2. On the Settings blade, choose Artifacts Repository

   ![Picture of the 'Settings' pane with the 'Artifact Repository' item selected in Azure DevTest Labs][azure-devtest-settings-pane]
   
3. On the Artifacts Repository blade
   1. Enter a display Name for the repo.
   2. Enter the saved Git Clone Url.
   3. Enter the Folder Path in the artifacts repo that contains the artifacts.
   4. Enter the saved Personal Access Token to the artifacts repo.
   5. Choose Save.

   ![The 'Artifact Repository' pane in Azure DevTest Labs][azure-devtest-lab-artifact-repo-pane]


[](---- COMMENT: Links to the various images used in this document ----)

[artifact-repo-github]: images/artifact-repo-github.png
[github-clone]: images/github-clone.png
[github-settings-item]: images/github-settings-item.png
[github-pat]: images/github-personal-access-tokens-ui.png
[azure-devtest-lab-settings]: images/azure-devtest-lab-settings.png
[azure-artifact-repo-settings]: images/azure-artifact-repo-settings.png
[vsts-choose-team]: images/vsts-choose-team.png
[code-tab-vsts]: images/vsts-tab-code.png
[vsts-clone-button]: images/vsts-clone-link-button.png
[vsts-clone-uri]: images/vsts-clone-uri.png
[vsts-profile-menu]: images/vsts-profile-menu.png
[vsts-security-tab]: images/vsts-security-tab.png
[vsts-security-pat-add]: images/vsts-pat-add.png
[vsts-create-pat]: images/vsts-create-pat.png
[vsts-copy-token]: images/vsts-copy-token.png
[azure-devtest-lab-settings-button]: images/azure-devtest-lab-settings-button.png
[azure-devtest-settings-pane]: images/azure-devtest-settings-pane.png
[azure-devtest-lab-artifact-repo-pane]: images/azure-devtest-lab-artifact-repo-pane.png
