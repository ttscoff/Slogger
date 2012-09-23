#RSS Feed Resource for Brett Terpstra's Slogger

I hacked this together from numerous places as a resource for those using [Slogger](https://github.com/ttscoff/Slogger) (graciously offered by Brett Terpstra). 

I have tried to use ALL_CAPS in the feeds to note those areas that will require your specific info.  

Feel free to share the list and make additions. And please let me know if there is anything here that needs correcting.

##App.net
* Feed  
	* https://alpha-api.app.net/feed/rss/users/USERNAME/posts  
* Hashtag  
	* https://alpha-api.app.net/feed/rss/posts/tag/HASHTAG  

##Blogger
* Feed
	* http://BLOGNAME.blogspot.com/rss.xml 

##Dropbox
* Feed  
	* https://www.dropbox.com/123456/7891011/a12b345/events.xml  

		Note:  – Via the Dropbox web interface, enable RSS feeds under your Dropbox Settings. While still in the webinterface, go to your Events page or use the URL http://dropbox.com/events. Scroll to bottom of page and look for"Subscribe to this feed." link and click on it to get the feed for all your Dropbox events.  
 
##Dropmark
* Feed  
	* http://demo.dropmark.com/110 becomes http://demo.dropmark.com/110.rss  

		Note: Add ".rss" to your collection URL to get a direct link to its RSS feed.  

##Evernote  
* Feed  
	* https://www.evernote.com/pub/USERNAME/NOTEBOOK/feed  

		Note: you can also get the RSS feed for any shared notebook on Evernote.  

##Facebook  
* Feed - Individual Profile  
	* No RSS feeds for individual profiles.  
* Feed - Facebook Pages  
	* https://www.facebook.com/feeds/page.php?format=atom10&id=FACEBOOK_ID  

		Note: If you don't have a custom page URL, your FACEBOOK_ID will show up when you access the page. If you do have a custompage URL, go to the FB page, scroll down to the 'like this' link, right click and copy link. Then paste it in yourtext editor or somewhere else to view your ID.

##Flickr  
* Feed - User  
	* http://api.flickr.com/services/feeds/photos_public.gne?id=FLICKR_ID  

		Note: use http://idgettr.com to get your FLICKR_ID.  
* Feed - Tags (separate tags with commas)  
	* http://api.flickr.com/services/feeds/photos_public.gne?tags=<t1>,<t2>  

##Foursquare  
* Feed  
	* https://feeds.foursquare.com/history/ABCD.rss  

		Note:  Via the Foursquare web interface, enter URL http://foursquare.com/feeds/ after signing in.  

##Instagram  
* Feed - Tags  
	* http://instagr.am/tags/TAG/feed/recent.rss  

		Note: There is not an official Instagram feed for individual users, but there are third party services that can do so Perform a Google search for options.  
		One option is Webstagram - http://web.stagram.com  
		Create account that will access your Instagram account.  
		Feed will be in the form of http://widget.stagram.com/rss/n/INSTAGRAM_ID/  

##InstaPaper  
* Feed  
	* http://www.instapaper.com/rss/123/456  

		Note: – Via the Instapaper web interface, scroll to the bottom of the page for "This folder's RSS" link.

##LinkedIn  
* Feed  
	* http://www.linkedin.com/rss/nus?key=ABCDEF  

		Note:  Via the LinkedIn web interface, enter URL http://www.linkedin.com/rssAdmin?display= after signing in.

##Picasa  

* Feed - Search query  
	* http://photos.googleapis.com/data/feed/base/all?alt=rss&kind=photo&q=SEARCH_TERM  

##Pinterest  
* Feed - User  
	* http://pinterest.com/USERNAME/feed.rss  
* Feed - Board  
	* http://pinterest.com/USERNAME/BOARD_NAME/rss  

##StumbleUpon   
* Feed  
	* http://rss.stumbleupon.com/user/USERNAME/favorites  

##Twitter  
* Feed - User Timeline  
	* https://twitter.com/statuses/user_timeline/USERNAME.rss  
* Feed - Favorite Tweets  
	* https://api.twitter.com/1/favorites/USERNAME.rss  
* Feed - @Mentions  
	* http://search.twitter.com/search.rss?q=to:@USERNAME  
* Feed - Hashtag or Search query  
	* http://search.twitter.com/search.rss?q=QUERY  
* Feed - Twitter List  
	* https://api.twitter.com/1/USERNAME/lists/LISTNAME/statuses.atom  

		Note: if LISTNAME contains two or more words with spaces between them, use %20 as the separator in place of the space.  

##Tumblr  
* Feed  
	* http://BLOG_NAME.tumblr.com/rss 
* Feed - Tag  
	* http://BLOG_NAME.tumblr​.com/​t​a​g​g​e​d​/​TAG_NAME/​rss  

##WordPress hosted  
* Feed  
	* http://BLOG_NAME.wordpress.com/feed/  
* Feed - Tag  
	* http://BLOG_NAME.wordpress.com/tag/TAG_NAME/feed/  

##YouTube  
* Feed - Recent uploads  
	* https://gdata.youtube.com/feeds/api/users/USERNAME/uploads  
* Feed - Tag  
	* https://gdata.youtube.com/feeds/api/videos/-/TAG  
* Feed - Search query  
	* https://gdata.youtube.com/feeds/api/videos?q=QUERY  

		Note: you can add the following after QUERY to refine:  
			&orderby=relevance  
			&orderby=published  
			&orderby=viewCount  
	
##For services that do not offer an RSS feed  
	
* Determine if there is a way to post the data to Twitter. If so, you're in business. You can simply post to your current Twitter account and pull in via Slogger.  
* Or, if you don't want to clutter up your regular Twitter account, create a new one to house these feeds and add thenewly created Twitter account to Slogger.  