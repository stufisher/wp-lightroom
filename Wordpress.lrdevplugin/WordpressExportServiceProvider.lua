-- Wordpress Publish Service
-- by Stu Fisher http://q3f.org
--
-- Allows you to post from Lightroom -> Wordpress

local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrHttp = import 'LrHttp'
local LrLogger = import 'LrLogger'
local LrXml = import 'LrXml'
local LrDate = import 'LrDate'
local LrErrors = import 'LrErrors'

local myLogger = LrLogger( 'Wordpress' )
myLogger:enable( "print" )


local bind = LrView.bind
local share = LrView.share

local exportServiceProvider = {}

exportServiceProvider.supportsIncrementalPublish = 'only'
exportServiceProvider.small_icon = 'wordpress.png'

exportServiceProvider.exportPresetFields = {
	{ key = 'username', default = "" },
	{ key = 'password', default = "" },
	{ key = 'url', default = "" },
}

exportServiceProvider.hideSections = { 'exportLocation' }
exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.hidePrintResolution = true
exportServiceProvider.canExportVideo = false 

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )

	return {
	
		{
			title = LOC "$$$/Wordpress/ExportDialog/Account=Wordpress Account",

			f:row {
				spacing = f:control_spacing(),

				f:static_text {
					title = "Username",

				},

				f:edit_field {
					width = 90,
                    value = bind 'username',
                    
				},
                
                f:spacer { width = 5 },
                
				f:static_text {
					title = "Password",

				},

				f:password_field {
					width = 90,
                    value = bind 'password',
                    
				},

                f:spacer { width = 5 },

				f:static_text {
					title = "Blog Url",

				},

				f:edit_field {
					width = 120,
                    value = bind 'url',
                    
				},

			},
		},
	}

end

function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
	
	local exportSession = exportContext.exportSession
	local exportSettings = assert( exportContext.propertyTable )
	
	local nPhotos = exportSession:countRenditions()
	
	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
									and LOC( "$$$/Wordpress/Publish/Progress=Publishing ^1 photos to Wordpress", nPhotos )
									or LOC "$$$/Wordpress/Publish/Progress/One=Publishing one photo to Wordpress",
					}
	
	local uploadedPhotoIds = {}
	
	local publishedCollectionInfo = exportContext.publishedCollectionInfo

	local isDefaultCollection = publishedCollectionInfo.isDefaultCollection
	
	local photosetUrl

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do		
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )

		local photo = rendition.photo
		
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
			
			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
			
			if progressScope:isCanceled() then break end
			
			if success then
				local title = photo:getFormattedMetadata( 'title' )
				local description = photo:getFormattedMetadata( 'caption' )
				local keywordTags = photo:getFormattedMetadata( 'keywordTagsForExport' )
				
                if #title == 0 then
                    LrErrors.throwUserError( 'You need to enter a title for this image before it can be uploaded' )
                end

                if #description == 0 then
                    LrErrors.throwUserError( 'You need to enter a caption for this image before it can be uploaded' )
                end
                
				local tags
				
				if keywordTags then

					tags = {}

					local keywordIter = string.gfind( keywordTags, "[^,]+" )

					for keyword in keywordIter do
					
						if string.sub( keyword, 1, 1 ) == ' ' then
							keyword = string.sub( keyword, 2, -1 )
						end
						
						if string.find( keyword, ' ' ) ~= nil then
							keyword = '"' .. keyword .. '"'
						end
						
						tags[ #tags + 1 ] = keyword

					end

				end
            

                local filePath = assert( pathOrMessage )
                local fileName = LrPathUtils.leafName( filePath )
                
                local mimeChunks = {}

                mimeChunks[ #mimeChunks + 1 ] = { name = 'action', value = 'post' }
                
                if rendition.publishedPhotoId then
                    mimeChunks[ #mimeChunks + 1 ] = { name = 'post_id', value = rendition.publishedPhotoId }
                end
                
                mimeChunks[ #mimeChunks + 1 ] = { name = 'username', value = exportSettings.username }
                mimeChunks[ #mimeChunks + 1 ] = { name = 'password', value = exportSettings.password }
                mimeChunks[ #mimeChunks + 1 ] = { name = 'tags', value = table.concat( tags, ',' ) }
                mimeChunks[ #mimeChunks + 1 ] = { name = 'title', value = title }
                mimeChunks[ #mimeChunks + 1 ] = { name = 'desc', value = description }
                mimeChunks[ #mimeChunks + 1 ] = { name = 'photo', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }
                
                local result, hdrs = LrHttp.postMultipart( exportSettings.url .. '/?feed=lr', mimeChunks )
                
                if hdrs and hdrs.status == 403 then
                    LrErrors.throwUserError( 'Invalid wordpress username and/or password' )
                end              

				LrFileUtils.delete( pathOrMessage )
                
                myLogger:trace(tonumber(result))
                myLogger:trace(result)
                
                new_id = tonumber(result)
                
                if new_id == 0 then
                    LrErrors.throwUserError( 'Something went wrong uploading this image' )
                end
                
                if new_id ~= nil and new_id ~= 0 then
                    rendition:recordPublishedPhotoId( tonumber(result) )
                end
			end
			
		end

	end

	progressScope:done()
	
end

function exportServiceProvider.getCollectionBehaviorInfo( publishSettings )

	return {
		defaultCollectionName = LOC "$$$/Wordpress/DefaultCollectionName/Posts=Posts",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
	}
	
end


function exportServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = false,
		dateCreated = false,
	}

end

function exportServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )

	for i, photoId in ipairs( arrayOfPhotoIds ) do
        local mimeChunks = {}
    
        mimeChunks[ #mimeChunks + 1 ] = { name = 'action', value = 'delete' }    
        mimeChunks[ #mimeChunks + 1 ] = { name = 'username', value = publishSettings.username }
        mimeChunks[ #mimeChunks + 1 ] = { name = 'password', value = publishSettings.password }
        mimeChunks[ #mimeChunks + 1 ] = { name = 'post_id', value = photoId }
                        
        local result, hdrs = LrHttp.postMultipart( publishSettings.url .. '/?feed=lr', mimeChunks ) 
        
        if hdrs and hdrs.status == 403 then
            LrErrors.throwUserError( 'Invalid wordpress username and/or password' )
        end        
        
		deletedCallback( photoId )

	end
	
end

function exportServiceProvider.shouldReverseSequenceForPublishedCollection( publishSettings, collectionInfo )

	return collectionInfo.isDefaultCollection

end

exportServiceProvider.supportsCustomSortOrder = false
exportServiceProvider.disableRenamePublishedCollection = true
exportServiceProvider.disableRenamePublishedCollectionSet = true

function exportServiceProvider.renamePublishedCollection( publishSettings, info )
		
end

function exportServiceProvider.deletePublishedCollection( publishSettings, info )

end


function exportServiceProvider.getCommentsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, commentCallback )

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

        local commentList = {}		
        local mimeChunks = {}
        
        mimeChunks[ #mimeChunks + 1 ] = { name = 'action', value = 'get_comments' }
        mimeChunks[ #mimeChunks + 1 ] = { name = 'username', value = publishSettings.username }
        mimeChunks[ #mimeChunks + 1 ] = { name = 'password', value = publishSettings.password }
        mimeChunks[ #mimeChunks + 1 ] = { name = 'post_id', value = photoInfo.remoteId }
                        
        local result, hdrs = LrHttp.postMultipart( publishSettings.url .. '/?feed=lr', mimeChunks )
        
        if hdrs and hdrs.status == 403 then
            LrErrors.throwUserError( 'Invalid wordpress username and/or password' )
        end
                               
        local commentHeadElement = LrXml.parseXml( result )

        if commentHeadElement:childCount() > 0 then

            local commentsElement = commentHeadElement:childAtIndex( 1 )
            local numOfComments = commentsElement:childCount()

            for i = 1, numOfComments do

                local commentElement = commentsElement:childAtIndex( i )

                if commentElement then

                    local comment = {}
                    for k,v in pairs( commentElement:attributes() ) do
                        comment[ k ] = v.value
                    end
                    
                    if comment.date then
                        comment.date = LrDate.timeFromPosixDate( comment.date )
                    end
                    
                    comment.commentText = commentElement.text and commentElement:text()

                    table.insert( commentList, {
                                    commentId = comment.id,
                                    commentText = comment.commentText,
                                    dateCreated = comment.date,
                                    username = comment.author,
                                    realname = comment.author
                                } )

                end

			end		

		end	

        commentCallback { publishedPhoto = photoInfo, comments = commentList }
        
	end

end

function exportServiceProvider.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )

    local mimeChunks = {}
    
    mimeChunks[ #mimeChunks + 1 ] = { name = 'action', value = 'add_comment' }
    mimeChunks[ #mimeChunks + 1 ] = { name = 'username', value = publishSettings.username }
    mimeChunks[ #mimeChunks + 1 ] = { name = 'password', value = publishSettings.password }
    mimeChunks[ #mimeChunks + 1 ] = { name = 'comment', value = commentText }
    mimeChunks[ #mimeChunks + 1 ] = { name = 'post_id', value = remotePhotoId }
    
    local result, hdrs = LrHttp.postMultipart( exportSettings.url .. '/?feed=lr', mimeChunks )

    if hdrs and hdrs.status == 403 then
        LrErrors.throwUserError( 'Invalid wordpress username and/or password' )
    end
end





--------------------------------------------------------------------------------

return exportServiceProvider
