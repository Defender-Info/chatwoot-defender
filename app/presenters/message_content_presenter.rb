class MessageContentPresenter < SimpleDelegator
  def outgoing_content
    content_to_send = if should_append_survey_link?
                        survey_link = survey_url(conversation.uuid)
                        custom_message = inbox.csat_config&.dig('message')
                        custom_message.present? ? "#{custom_message} #{survey_link}" : I18n.t('conversations.survey.response', link: survey_link)
                      else
                        content
                      end

    rendered = Messages::MarkdownRendererService.new(
      content_to_send,
      conversation.inbox.channel_type,
      conversation.inbox.channel
    ).render

    should_prepend_agent_name? ? prepend_agent_name(rendered) : rendered
  end

  private

  def should_prepend_agent_name?
    outgoing? && sender.is_a?(User) && conversation.inbox.channel_type == 'Channel::Api'
  end

  def prepend_agent_name(text)
    agent_name = sender.available_name
    return text if agent_name.blank? || text.blank?

    "*#{agent_name}:*\n#{text}"
  end

  def should_append_survey_link?
    input_csat? && !inbox.web_widget?
  end

  def survey_url(conversation_uuid)
    "#{ENV.fetch('FRONTEND_URL', nil)}/survey/responses/#{conversation_uuid}"
  end
end
