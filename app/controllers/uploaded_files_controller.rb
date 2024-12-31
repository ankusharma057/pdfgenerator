class UploadedFilesController < ApplicationController
  require 'combine_pdf'
  require 'prawn'
  require 'httparty'
  require "google/cloud/translate"

  def new
    @uploaded_file = UploadedFile.new
  end

  def create
    @uploaded_file = UploadedFile.new(uploaded_file_params)
    if @uploaded_file.save
      if File.extname(@uploaded_file.file.path).downcase == '.pdf'
        pdf = CombinePDF.load(@uploaded_file.file.path)

        if pdf.pages.size > 3
          target_language = params[:uploaded_file][:target_language] 
          adjusted_pdf_path = adjust_pdf_content(pdf, @uploaded_file.file.filename, target_language)
          @uploaded_file.update(file: File.open(adjusted_pdf_path))
        end
      end

      redirect_to uploaded_file_path(@uploaded_file), notice: 'File uploaded and translated successfully!'
    else
      render :new, alert: 'File upload failed.'
    end
  end

  def show
    @uploaded_file = UploadedFile.find(params[:id])
  end

  private

  def uploaded_file_params
    params.require(:uploaded_file).permit(:file)
  end

  def adjust_pdf_content(pdf, original_filename, target_language)
    adjusted_pdf_path = Rails.root.join('tmp', "translated_#{original_filename}")
    reader = PDF::Reader.new(@uploaded_file.file.path)

    Prawn::Document.generate(adjusted_pdf_path, page_size: 'A4') do |doc|
      reader.pages.each_with_index do |page, index|
        translated_text = translate_text(page.text, target_language)

        doc.start_new_page unless index.zero?
        doc.bounding_box([0, doc.cursor], width: doc.bounds.width, height: doc.bounds.height) do
          doc.text translated_text, size: 10
        end
      end
    end

    adjusted_pdf_path
  end

	def translate_text(text, target_language)
	  api_key = "AIzaSyCnjBDKJ8JQIJ9iKE8oYYBYb0U2q5UrLXY"  
	  url = "https://translation.googleapis.com/language/translate/v2"
	  
	  response = HTTParty.post(url, {
	    body: {
	      q: text,
	      target: target_language,
	      key: api_key  
	    }.to_json,
	    headers: { 'Content-Type' => 'application/json' }
	  })

	  if response.code == 200
	    response.parsed_response['data']['translations'][0]['translatedText']
	  else
	    Rails.logger.error("Translation API Error: #{response.body}")
	    "Translation failed. Original text: #{text}"
	  end
	end

end
