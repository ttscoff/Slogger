# RSS Feed list

Compiled by rreeger <https://gist.github.com/3388024>

- - -

RSS Feed Resource for Brett Terpstra's Slogger

I hacked this together from numerous places as a resource for those using Slogger (graciously offered by Brett Terpstra). Feel free to share the list and make additions. And please let me know if there is anything here that needs correcting.

Blogger

	Feed
	http://<blogname>.blogspot.com/rss.xml 



Dropbox

	https://www.dropbox.com/123456/7891011/a12b345/events.xml
	Note:  – Via the Dropbox web interface, enable RSS feeds under your Dropbox Settings. While still in the web interface, go to your Events page or use the URL http://dropbox.com/events. Scroll to bottom of page and look for "Subscribe to this feed." link and click on it to get the feed for all your Dropbox events.



Evernote 

	https://www.evernote.com/pub/<username>/<notebook>/feed 
	Note: you can also get the RSS feed for any shared notebook on Evernote.



Facebook

	No RSS feeds for individual profiles.
	
	Facebook Pages
	https://www.facebook.com/feeds/page.php?format=atom10&id=<ID> 
	Note: If you don't have a custom page URL, your ID will show up when you access the page. If you do have a custom page URL, go to the FB page, scroll down to the 'like this' link, right click and copy link. Then paste it in your text editor or somewhere else to view your ID.



Flickr

	User feed
	http://api.flickr.com/services/feeds/photos_public.gne?id=<ID> 
	Note: use http://idgettr.com to get your ID.
	
	Tags (separate tags with commas)
	http://api.flickr.com/services/feeds/photos_public.gne?tags=<t1>,<t2> 	



Foursquare

	https://feeds.foursquare.com/history/ABCD.rss
	Note:  Via the Foursquare web interface, enter URL http://foursquare.com/feeds/ after signing in.



Instagram 

	Tags
	http://instagr.am/tags/<tag>/feed/recent.rss 
	Note: There is not an official Instagram feed for individual users, but there may be third party services that can do so. Perform a Google search for options.



InstaPaper

	http://www.instapaper.com/rss/123/456
	Note: – Via the Instapaper web interface, scroll to the bottom of the page for "This folder's RSS" link.



LinkedIn

	http://www.linkedin.com/rss/nus?key=abcdef
	Note:  Via the LinkedIn web interface, enter URL http://www.linkedin.com/rssAdmin?display= after signing in.



Picasa

	Search query
	http://photos.googleapis.com/data/feed/base/all?alt=rss&kind=photo&q=<search>  



Pinterest

	User feed
	http://pinterest.com/<user>/feed.rss 
	
	Board feed
	http://pinterest.com/<user>/<board>/rss 



StumbleUpon 

	http://rss.stumbleupon.com/user/<username>/favorites 



Twitter

	User Timeline
	https://twitter.com/statuses/user_timeline/<username>.rss 
	
	Favorite Tweets
	https://api.twitter.com/1/favorites/<username>.rss 
	
	@Mentions
	http://search.twitter.com/search.rss?q=to:@<username>  
	
	Hashtag or Search query
	http://search.twitter.com/search.rss?q=<query> 
	
	Twitter List
	https://api.twitter.com/1/<username>/lists/<listname>/statuses.atom 
		Note: if <listname> contains two or more words with spaces between them, use %20 as the separator in place of the space.



Tumblr

	Feed
	http://<blogname>.tumblr.com/rss 

	Tag
	http://<blogname>.tumblr​.com/​t​a​g​g​e​d​/​<tag-name>/​rss



WordPress hosted

	Feed
	http://<blogname>.wordpress.com/feed/ 

	Tag
	http://<blogname>.wordpress.com/tag/<tag-name>/feed/



YouTube

	Recent uploads
	https://gdata.youtube.com/feeds/api/users/<user>/uploads 
	
	Tag
	https://gdata.youtube.com/feeds/api/videos/-/<tag> 
	
	Search query
	https://gdata.youtube.com/feeds/api/videos?q=<query> 
	Note: you can add the following after <query> to refine:
		&orderby=relevance
		&orderby=published
		&orderby=viewCount
	

For services that do not offer an RSS feed
	
	Determine if there is a way to post the data to Twitter. If so, you're in business. You can simply post to your current Twitter account and pull in via Slogger. 
	Or, if you don't want to clutter up your regular Twitter account, create a new one to house these feeds and add the newly created Twitter account to Slogger.

















