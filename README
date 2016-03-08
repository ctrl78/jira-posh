JIRA PowerShell Toolkit
=======================

This is pretty rough at the moment and offers the bare minimum to be able to
construct PowerShell scripts that can access JIRA in a convenient manner.

You can use the toolkit in an interactive manner by importing the module to your
current environment:

    > cd .\jira-posh
    > Import-Module .\jira-posh

Set your JIRA credentials but note that these are insecurely stored in the Windows
Environment in base64 encoded form:

    > Set-JiraCredentials

    cmdlet Set-JiraCredentials at command pipeline position 1
    Supply values for the following parameters:
    username: adam.piper
    password:


Add Functions

    > Add-JiraIssue
    > Add-JiraComment
    >  
  

Get Functions

    > Get-JiraIssue LCSIL-7212
    > Get-JiraHistory
    
  

Or the Get-JiraSearchResult function to provide a query in JQL:

    > Get-JiraSearchResult "id = LCSIL-7217"


    expand     : names,schema
    startAt    : 0
    maxResults : 50
    total      : 1
    issues     : {@{expand=editmeta,renderedFields,transitions,changelog,operations; id=742567;
                 self=https://jira.isg.co.uk/rest/api/latest/issue/742567; key=LCSIL-7217; fields=}}
