class UploadedFile < ApplicationRecord
	mount_uploader :file, FileUploader
end
