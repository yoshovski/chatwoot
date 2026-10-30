# Builds the TeXML documents served to Telnyx. TeXML follows TwiML's verbs and attributes.
# https://developers.telnyx.com/docs/voice/programmable-voice/texml-verbs/conference
module Voice::Provider::Telnyx::Texml
  module_function

  # The agent leg starts the conference and ends it on hang-up; the contact waits for the agent.
  # `callbacks` carries the :status and :recording webhook URLs.
  def conference(name, participant_label:, agent:, record:, callbacks:)
    attributes = {
      participantLabel: participant_label,
      startConferenceOnEnter: agent.to_s,
      endConferenceOnExit: agent.to_s,
      beep: 'false',
      record: record ? 'record-from-start' : 'do-not-record',
      statusCallback: callbacks[:status],
      statusCallbackEvent: 'start end join leave',
      statusCallbackMethod: 'POST'
    }
    if record
      attributes.merge!(recordingStatusCallback: callbacks[:recording], recordingStatusCallbackEvent: 'completed',
                        recordingStatusCallbackMethod: 'POST')
    end

    document { |xml| xml.Dial { xml.Conference(name, attributes) } }
  end

  def hangup
    document(&:Hangup)
  end

  def document
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |xml| xml.Response { yield xml } }.to_xml
  end
end
