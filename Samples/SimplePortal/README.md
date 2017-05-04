
## Overview

This sample demonstrates the usage of Dev Test Lab Rest apis [listed](https://azure.github.io/projects/apis/) here. The sample is a comprehensive end to end web app providing the user view of the Dev Test lab. With this App users of Dev Test lab can accomplish the following operations. 
1) List all Virtual Machines owned in a lab. 
2) Create a new Virtual Machine. 
3) Do basic operations on Virtual machines like Start, Stop, Delete on a particular VM. 
4) ClaimAnyVM and Claim a particular VM in the lab. 

The App is written in React JS + TypeScript and is intended to be a sample for consuming Dev Test lab rest api's. 

## Prerequisites 
This app uses Azure Active Directory based [OAuth2 implicit grant flow](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-dev-understanding-oauth2-implicit-grant) based authentication. To enable this you need to do the following steps 


### Registering the App in Azure active directory ###
To register a new application we need to first create the  App registrations in Azure Active directory. To know more about this please follow this [link](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-integrating-applications). We need t


+ Sign in to the [Azure portal](https://portal.azure.com)
+ Choose your Azure AD tenant by selecting your account in the top right corner of the page
+ In the left-hand navigation pane, choose More Services, click App Registrations, and click Add
+ Follow the prompts and create a new application
+ Once the app is created, grant delegated permissions to Windows Azure Active Directory (Microsoft.Azure.ActiveDirectory) and Windows Azure Service Management API in the Required permissions Settings blade 
+ Generate a valid key and copy it.
+ Register your App URL and http://localhost:3000 in the Reply URL's section 

###Code Change
 You need to update the client ID and Redirect URI's that we pass to Oauth 2 end point in the code. 

+ Copy the Client ID/Application ID from the portal and update in src\components\Login.tsx
+ Update the Redirect URI to your App URL that you have registered in the Reply URL's


## Running the App


### Installing a Dependency

The generated project includes React and ReactDOM as dependencies. It also includes a set of scripts used by Create React App as a development dependency. You may install other dependencies (for example, React Router) with `npm`:

```
npm install --save <library-name>
```

In the project directory, you can run:

### `npm start`

Runs the app in the development mode.<br>
Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

The page will reload if you make edits.<br>
You will also see any lint errors in the console.

### `npm run build`

Builds the app for production to the `build` folder.<br>
It correctly bundles React in production mode and optimizes the build for the best performance.

The build is minified and the filenames include the hashes.<br>
Your app is ready to be deployed!




