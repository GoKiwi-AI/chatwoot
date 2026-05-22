class Captain::Tools::ShopifyNext::BaseTool < Captain::Tools::BasePublicTool
  def active?
    shopify_next_hook.present? && (shopify_next_hook.settings || {}).fetch('enabled_for_captain', true)
  end

  private

  def shopify_next_hook
    @shopify_next_hook ||= @assistant.account.hooks.find_by(app_id: 'shopify_next', status: 'enabled')
  end

  def storefront_client
    Integrations::ShopifyNext::StorefrontMcpClient.new(shopify_next_hook)
  end

  def admin_client
    Integrations::ShopifyNext::AdminClient.new(shopify_next_hook)
  end

  def call_storefront_tool(name, arguments = {})
    return 'Shopify Next is not connected' unless shopify_next_hook

    format_json(storefront_client.call_tool(name, arguments.compact))
  rescue StandardError => e
    Rails.logger.error("Shopify Next Storefront MCP tool error: #{e.class} - #{e.message}")
    'I could not access Shopify storefront data right now'
  end

  def call_admin_tool
    return 'Shopify Next is not connected' unless shopify_next_hook

    format_json(yield(admin_client))
  rescue StandardError => e
    Rails.logger.error("Shopify Next Admin tool error: #{e.class} - #{e.message}")
    'I could not access Shopify admin data right now'
  end

  def format_json(payload)
    JSON.pretty_generate(payload)
  rescue StandardError
    payload.to_s
  end

  def contact_email(state)
    state&.dig(:contact, :email).presence
  end

  def contact_phone(state)
    state&.dig(:contact, :phone_number).presence
  end

  def shopify_context(state)
    conversation = state&.dig(:conversation) || {}
    custom_context = conversation.dig(:custom_attributes, 'shopify_next') || conversation.dig(:custom_attributes, :shopify_next)
    additional_context = conversation.dig(:additional_attributes, 'shopify_next') || conversation.dig(:additional_attributes, :shopify_next)

    (custom_context || additional_context || {}).with_indifferent_access
  end

  def context_cart_id(state)
    context = shopify_context(state)
    cart_id = preferred_cart_identifier(context[:cart_id], context[:cart_token])
    return if cart_id.blank?

    cart_id.start_with?('gid://shopify/Cart/') ? cart_id : "gid://shopify/Cart/#{cart_id}"
  end

  def preferred_cart_identifier(cart_id, cart_token)
    identifiers = [cart_id, cart_token].compact_blank

    identifiers.find { |identifier| identifier.include?('?key=') } || identifiers.first
  end

  def context_cart_snapshot(state)
    cart = shopify_context(state)[:cart]
    return {} if cart.blank?

    cart.with_indifferent_access
  end
end
