#*******************************************************************************
# clipboard_image_paste Redmine plugin.
#
# Attachment patch converting uploaded pasted image data to file object.
#
# Authors:
# - Richard Pecl
# - Alexandr Ivanov: conversion code snippet from
#   redmine_cr_img_paste plugin
#
# Terms of use:
# - GNU GENERAL PUBLIC LICENSE Version 2
#*******************************************************************************
module ClipboardImagePaste
module AttachmentPatch
  # go through attachments and find keys starting by 100;
  # image attachments are identified by key >= 10001, the keys should be numbers
  # 'cause acts_as_attachable is sorting them according to insertion order
  def save_attachments(attachments, author=User.current)
    if attachments && attachments.is_a?(ActionController::Parameters)
      attachments.each do |key,value|
        next unless key.start_with?('1000')
        value['file'] = PastedImage.new(value.delete('data'), value.delete('name'))
      end
    end
    super(attachments, author)
  end

  # Mimics uploaded file field data.
  class PastedImage
    def initialize(data, name)
      @raw = StringIO.new(remove_alpha(Base64.decode64(data.to_s)))
      @name = name.to_s.strip
      @name = 'picture.png' if @name.blank?
      @name += '.png' unless @name.end_with?('.png')
    end

    def size
      @raw.size
    end

    def original_filename
      @name
    end

    def content_type
      "image/png"
    end

    def read(*args)
      @raw.read(*args)
    end

    def eof?
      @raw.eof?
    end

    # remove alpha channel (because PDF export doesn't support PNGs with alpha channel,
    # see https://github.com/peclik/clipboard_image_paste/issues/24)
    def remove_alpha(imgData)
      begin
        ilist = Magick::ImageList.new
        ilist.from_blob(imgData)
        ilist.each do |img|
          # border function will compose alpha channel with border color
          img.border!(0, 0, "white")
          # deactivating alpha channel ('alpha -off') will skip it during image saving
          img.alpha(Magick::DeactivateAlphaChannel)
        end
        return ilist.to_blob
      rescue
        return imgData
      end
    end if $clipboard_image_paste_remove_alpha && Object.const_defined?(:Magick)

    # without RMagick we cannot remove alpha channel
    def remove_alpha(imgData)
      return imgData
    end if not ($clipboard_image_paste_remove_alpha && Object.const_defined?(:Magick))
  end

end
end

# Send patches - guarded against including the module multiple time
# (like in tests) and registering multiple callbacks

[Issue, News, WikiPage, Message, Document, Version, Project].each do |klass|
  unless klass.included_modules.include? ClipboardImagePaste::AttachmentPatch
    klass.prepend(ClipboardImagePaste::AttachmentPatch)
  end
end

# KbArticle plug-in (https://github.com/alexbevi/redmine_knowledgebase)
begin
  unless KbArticle.included_modules.include? ClipboardImagePaste::AttachmentPatch
    KbArticle.prepend(ClipboardImagePaste::AttachmentPatch)
  end
rescue NameError => e
  # plug-in not installed
end
