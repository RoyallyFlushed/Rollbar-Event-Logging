# Rollbar-Event-Logging
#### A lightweight self-contained system for logging events &amp; errors using Rollbar on Roblox

### About

This is a simple, lightweight, self-contained system which allows developers to catch logged events and post them to the popular event tracking tool [Rollbar](https://rollbar.com/). This project isn't finished and is something I have been working on casually for a little while now; although I have put it on hold recently.

A common problem that I have experienced during my time as a Roblox Developer is catching errors that happen in your experiences so you can figure out exactly what is going wrong. 

More often than not, when a player reports a bug, they do not have a screenshot of their client log. Even on the off chance that they do, sometimes the error is server-side and so only a developer would have been able to see the issue. This is extremely frustrating as solving bugs in software is made exponentially easier if you have some kind of error output to work with.

Although I've often had the chance to voice these concerns with Roblox during their 1-1 feedback sessions, unfortunately we are yet to see a more effective way to interact with each game instance's logs.

A common solution that is often employed is to use an analytical tool such as GameAnalytics to take care of this for you. Another solution is to crudely post these errors to some site that isn't designed for this task. (Discord, Trello, Etc.). My issue with these methods is that they aren't all that perfect at logging things properly, and can often eat up a lot of your HTTP requests in doing so.

My goal for this project is to create a system which will be able to seemlessly and silently collect the logs of all connected clients, and the server, and process them smartly so that they can then be sent to an external logging service.

Processing logs is an interesting task. On one hand, you don't want to repeatedly log the same error, or similar errors, but instead you want to log unique errors; this can be challenging as now you enter the realm of string comparisons. For example, if there is a particular bug happening for a number of clients, we only really need to log the bug once, not for every single client. Sometimes however, this may not be desireable and so it is important to process logs carefully to converge to a desirable solution.

Ultimately, once this project is finished, keeping track of logs should be significantly easier, allowing for a much less stressful time debugging code.
