## Google

Google's OAuth integration allows us to specify multiple callback URLs, so we will only need to do this once for each wiki server.

### Register an application with Google

<!-- Notes: Based on Auth0 docs - see https://auth0.com/docs/connections/social/google -->

* While logged onto your Google account, goto the [API Manager](https://console.developers.google.com/)
* From the project dropdown at the top of the page, select **Create a project...**

![Google APIs Project Selector](./images/google-new-app.png)

* Enter a Project name, in the New Project dialog, and click **Create**

It will take a moment for Google to create your new project. Once it has been created you will receive a notification, and the page should switch to your new project. *Your new project name will appear in the project dropdown. If it does not, select your new project from the project dropdown.*

* Select **Credentials**, in the left sidebar, and then select the **OAuth consent screen** tab.

![Google OAuth consent screen](./images/google-oauth-consent.png)


### Step 2
