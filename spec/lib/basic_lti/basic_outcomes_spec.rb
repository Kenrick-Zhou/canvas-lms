#
# Copyright (C) 2013 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

describe BasicLTI::BasicOutcomes do
  before(:each) do
    course_model
    @root_account = @course.root_account
    @account = account_model(:root_account => @root_account, :parent_account => @root_account)
    @course.update_attribute(:account, @account)
    @user = factory_with_protected_attributes(User, :name => "some user", :workflow_state => "registered")
    @course.enroll_student(@user)
  end

  let(:tool) do
    @course.context_external_tools.create(:name => "a", :url => "http://google.com", :consumer_key => '12345', :shared_secret => 'secret')
  end

  let(:assignment) do
    @course.assignments.create!(
      {
          title: "value for title",
          description: "value for description",
          due_at: Time.now,
          points_possible: "1.5",
          submission_types: 'external_tool',
          external_tool_tag_attributes: {url: tool.url}
      }
    )
  end

  let(:source_id) { BasicLTI::BasicOutcomes.encode_source_id(tool, @course, assignment, @user) }

  let(:xml) do
    Nokogiri::XML.parse %Q{
      <?xml version = "1.0" encoding = "UTF-8"?>
      <imsx_POXEnvelopeRequest xmlns = "http://www.imsglobal.org/services/ltiv1p1/xsd/imsoms_v1p0">
        <imsx_POXHeader>
          <imsx_POXRequestHeaderInfo>
            <imsx_version>V1.0</imsx_version>
            <imsx_messageIdentifier>999999123</imsx_messageIdentifier>
          </imsx_POXRequestHeaderInfo>
        </imsx_POXHeader>
        <imsx_POXBody>
          <replaceResultRequest>
            <resultRecord>
              <sourcedGUID>
                <sourcedId>#{source_id}</sourcedId>
              </sourcedGUID>
              <result>
                <resultScore>
                  <language>en</language>
                  <textString>0.92</textString>
                </resultScore>
                <resultData>
                  <text>text data for canvas submission</text>
                </resultData>
              </result>
            </resultRecord>
          </replaceResultRequest>
        </imsx_POXBody>
      </imsx_POXEnvelopeRequest>
    }
  end

  describe "#handle_replaceResult" do
    it "accepts a grade" do
      xml.css('resultData').remove
      request = BasicLTI::BasicOutcomes.process_request(tool, xml)

      request.code_major.should == 'success'
      request.handle_request(tool).should be_true
      submission = assignment.submissions.where(user_id: @user.id).first
      submission.grade.should == (assignment.points_possible * 0.92).to_s
    end

    it "accepts a result data without grade" do
      xml.css('resultScore').remove
      request = BasicLTI::BasicOutcomes.process_request(tool, xml)
      request.code_major.should == 'success'
      request.handle_request(tool).should be_true
      submission = assignment.submissions.where(user_id: @user.id).first
      submission.body.should == 'text data for canvas submission'
      submission.grade.should be_nil
      submission.workflow_state.should == 'submitted'
    end

    it "fails if neither result data or a grade is sent" do
      xml.css('resultData').remove
      xml.css('resultScore').remove
      request = BasicLTI::BasicOutcomes.process_request(tool, xml)
      request.code_major.should == 'failure'
    end
  end
end
