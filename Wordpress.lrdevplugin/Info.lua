-- Wordpress Publish Service
-- by Stu Fisher http://stu-fisher.org
--
-- Allows you to post from Lightroom -> Wordpress

return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0,
	LrToolkitIdentifier = 'com.adobe.lightroom.export.wordpress',
	LrPluginName = LOC "$$$/Wordpress/PluginName=Wordpress",
	
	LrExportServiceProvider = {
		title = LOC "$$$/Wordpress/Wordpress-title=Wordpress",
		file = 'WordpressExportServiceProvider.lua',
	},

	VERSION = { major=1, minor=0, revision=0, build=1, },

}
