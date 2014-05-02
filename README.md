jira-diff
=========

Produce a diff for all SVN commits referencing a particular Jira ticket.

In ordering to make a commit available for diffing by this script, the commit message should be prefixed with:
```
[JIRASPACE-TICKETNUMBER]
```

The script is currently configured to only work for the repositories of the LDP team but may be extended in the future to be more generic.

Installation
============

```
$ sh install.sh
```

This will copy the jira-diff script into `/usr/local/bin` and make it executable for the current user.

Usage
=====

To view a list of available commands:
```
$ jira-diff -help
```

To produce a diff of the work so far on a particular task, specify the Jira ticket number for that task:
```
$ jira-diff 1400
```

To export the individual `.diff` files of the above command:
```
$ jira-diff 1400 -export
```
