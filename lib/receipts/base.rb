module Receipts
  class Base < Prawn::Document
    attr_accessor :title, :subtitle, :company, :amount_gross, :amount_net, :currency, :total_text, :payment_link, :total_text_in_words

    class << self
      attr_reader :title, :subtitle, :amount_gross, :amount_net, :currency, :total_text, :payment_link, :total_text_in_words
    end

    def initialize(attributes = {})
      super(page_size: attributes.delete(:page_size) || "LETTER")
      setup_fonts attributes.fetch(:font, Receipts.default_font)

      @title = attributes.fetch(:title, self.class.title)
      @subtitle = attributes.fetch(:subtitle, self.class.subtitle)
      @amount_gross = attributes.fetch(:amount_gross, self.class.amount_gross)
      @amount_net = attributes.fetch(:amount_net, self.class.amount_net)
      @currency = attributes.fetch(:currency, self.class.currency)
      @payment_link = attributes.fetch(:payment_link, self.class.payment_link)&.with_indifferent_access
      @total_text = attributes.fetch(:total_text, self.class.total_text)
      @total_text_in_words = attributes.fetch(:total_text_in_words, self.class.total_text_in_words)
      generate_from(attributes)
    end

    def generate_from(attributes)
      return if attributes.empty?

      company = attributes.fetch(:company)
      header company: company, height: attributes.fetch(:logo_height, 16)
      render_details attributes.fetch(:details)
      render_billing_details company: company, recipient: attributes.fetch(:recipient)
      render_line_items(
        line_items: attributes.fetch(:line_items),
        column_widths: attributes[:column_widths]
      )
      render_totals(total_items: attributes.fetch(:total_items), column_widths: attributes[:total_items_column_widths])
      render_signature(company: company)
      render_footer attributes.fetch(:footer, default_message(company: company))
    end

    def setup_fonts(custom_font = nil)
      if !!custom_font
        font_families.update "Primary" => custom_font
        font "Primary"
      end

      font_size 8
    end

    def load_image(logo)
      if logo.is_a? String
        logo.start_with?("http") ? URI.parse(logo).open : File.open(logo)
      else
        logo
      end
    end

    def header(company: {}, height: 16)
      logo = company[:logo]

      if logo.nil?
        text company.fetch(:name), align: :right, style: :bold, size: 16, color: "4b5563"
      else
        image load_image(logo), height: height, position: :right
      end

      move_up height
      text title, style: :bold, size: 32
      text subtitle, style: :bold, size: 16, color: "333333"
    end

    def render_details(details, margin_top: 16)
      move_down margin_top
      table(details, cell_style: {borders: [], inline_format: true, padding: [2, 8, 3, 2]})
    end

    def render_billing_details(company:, recipient:, margin_top: 16, display_values: nil)
      move_down margin_top

      display_values ||= company.fetch(:display, [:address, :phone, :email])
      company_details = company.values_at(*display_values).compact.join("\n")

      line_items = [
        [
          {content: "<b>#{company.fetch(:seller_key)}</b>\n<b>#{company.fetch(:name)}</b>\n#{company_details}\n\n#{company.fetch(:iban_text)}", padding: [2, 12, 3, 2]},
          {content: Array(recipient).join("\n"), padding: [2, 12, 3, 2]}
        ]
      ]
      table(line_items, width: bounds.width, cell_style: {borders: [], inline_format: true, overflow: :expand, padding: [0, 12, 2, 0]})
    end

    def render_line_items(line_items:, margin_top: 30, column_widths: nil)
      move_down margin_top

      borders = line_items.length - 2

      table_options = {
        width: bounds.width,
        cell_style: {border_color: "eeeeee", inline_format: true},
        column_widths: column_widths
      }.compact
    
      table(line_items, table_options) do
        row(0).font_style = :bold
        row(0).background_color = '3C3D3A'
        row(0).text_color = 'FFFFFF'
        cells.padding = 6
        cells.borders = []
        row(0..borders).borders = [:bottom]
      end
    end

    def render_totals(total_items:, margin_top: 30, column_widths: nil)
      move_down margin_top

      # Define the payment table with a single cell
      payment_table_data = [
        [{content: "<link href='#{payment_link['url']}'><color rgb='326d92'><b>#{payment_link['text']}</b></color></link>", borders: [:left, :right, :top, :bottom], inline_format: true}]
      ]

      # Draw the payment table
      indent(20) do 
        table(payment_table_data, width: 100, position: :left) do
          cells.padding = 10
          cells.borders = [:left, :right, :top, :bottom]
          cells.border_color = '000000'  # Black border
          cells.align = :center  # Center horizontally
          cells.valign = :center 
        end
      end
  
      borders = total_items.length - 2
      last_row = total_items.length - 1


      table_options = {
        width: bounds.width * 0.41,
        cell_style: {border_color: "eeeeee", inline_format: true, padding: [0, 12, 2, 0]},
        column_widths: column_widths,
        position: :right
      }.compact
      move_up 50 
      
      table(total_items, table_options) do
        row(0).font_style = :bold
        row(last_row).background_color = 'F5F4F3'
        row(0).text_color = '333333'
        cells.padding = 6
        cells.borders = []
        row(0..borders).borders = [:bottom]
      end
      move_down margin_top
      text total_text, size: 16, style: :bold, align: :right, background_color: 'F5F4F3', color: '333333'
      move_down 2
      text total_text_in_words, size: 10, align: :right, background_color: 'F5F4F3', color: '333333'
    end

    def render_signature(company:, margin_top: 30)
      move_down margin_top
      gap = 20

      # Set the y-coordinate (vertical position) for both boxes to be the same
      y_position = cursor

      # First bounding box
      bounding_box([0, y_position], width: (bounds.width / 2) - (gap / 2), height: 50) do
        stroke_bounds
        if company.fetch(:collection_signature_text, '').present?
          text_box company.fetch(:collection_signature_text, ''), at: [8, 18], width: (bounds.width / 2) - (gap / 2), height: 20, align: :left
        end
      end

      # Second bounding box, positioned to the right of the first one with a gap
      bounding_box([(bounds.width / 2) + (gap / 2), y_position], width: (bounds.width / 2) - (gap / 2), height: 50) do
        stroke_bounds
        if company.fetch(:fullname_person_invoice_issuer, '').present?
          text_box company.fetch(:fullname_person_invoice_issuer, ''), at: [8, 35], width: (bounds.width / 2) - (gap / 2) - 10, height: 20, size: 8, align: :left, inline_format: true
        end
        if company.fetch(:issuer_signature_text, '').present?
          text_box company.fetch(:issuer_signature_text, ''), at: [8, 18], width: (bounds.width / 2) - (gap / 2) - 10, height: 20, align: :left, inline_format: true
        end
      end

    end

    def render_footer(message, margin_top: 30)
      move_down margin_top
      text message, inline_format: true
    end

    def default_message(company:)
      if company.fetch(:email,'').present?
        "#{company.fetch(:contact_text, 'Contact us:')}<color rgb='326d92'><link href='mailto:#{company.fetch(:email,'')}'><b>#{company.fetch(:email,'')}</b></link></color>."
      end
    end
  end
end
