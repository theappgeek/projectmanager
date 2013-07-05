require_dependency 'attachments_controller'  
require_dependency 'attachment' 

module RedmineContacts
  module Patches    
    
    module AttachmentsControllerPatch
      
      module InstanceMethods    

        def contacts_thumbnail
          size = params[:size].to_i
          size = 64 unless size > 0          
          if @attachment.readable? && @attachment.thumbnailable?
            if Redmine::Thumbnail.convert_available?
              target = File.join(@attachment.class.thumbnails_storage_path, "#{@attachment.id}_#{@attachment.digest}_#{size}.thumb")
              thumbnail = RedmineContacts::Thumbnail.generate(@attachment.diskfile, target, size)        
            else
              thumbnail = @attachment.diskfile
            end 

            if stale?(:etag => @attachment.digest)
              send_file thumbnail, :filename => (request.env['HTTP_USER_AGENT'] =~ %r{MSIE} ? ERB::Util.url_encode(@attachment.filename) : @attachment.filename),
                                              :type => detect_content_type(@attachment),
                                              :disposition => 'inline'
            end
          else
            # No thumbnail for the attachment or thumbnail could not be created
            render :nothing => true, :status => 404
          end      
        rescue => e
          logger.error "An error occured while generating contact thumbnail for #{@attachment.disk_filename} to #{target}\nException was: #{e.message}" if logger
          return nil
        end 

      end
  
      def self.included(base) # :nodoc: 
        base.send(:include, InstanceMethods)
      end
        
    end
    
    module AttachmentPatch   
      
      module InstanceMethods    
        
        def is_contacts_thumbnailable?
          (self.is_pdf? && self.filesize < 600.kilobytes) || self.image?
        end
        
        def is_pdf?
          self.filename =~ /\.(pdf)$/i
        end
         
      end
  
      def self.included(base) # :nodoc: 
        base.send :include, InstanceMethods
      end  
      
    end     
    
    
  end
end  


unless Attachment.included_modules.include?(RedmineContacts::Patches::AttachmentPatch)
  Attachment.send(:include, RedmineContacts::Patches::AttachmentPatch)
end

unless AttachmentsController.included_modules.include?(RedmineContacts::Patches::AttachmentsControllerPatch)
  AttachmentsController.send(:include, RedmineContacts::Patches::AttachmentsControllerPatch)
end
