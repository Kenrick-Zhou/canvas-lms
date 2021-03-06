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

require File.expand_path(File.dirname(__FILE__) + '/../../sharding_spec_helper.rb')
require File.expand_path(File.dirname(__FILE__) + '/../../cassandra_spec_helper')

describe GradeChangeAuditApiController do
  it_should_behave_like "cassandra audit logs"

  before do
    RequestContextGenerator.stubs( :request_id => 'xyz' )

    @account = Account.default
    @sub_account = Account.create!(:parent_account => @account)
    @sub_sub_account = Account.create!(:parent_account => @sub_account)

    course_with_teacher(account: @sub_sub_account)
    student_in_course

    @assignment = @course.assignments.create!(:title => 'Assignment', :points_possible => 10)
    @submission = @assignment.grade_student(@student, grade: 8, grader: @teacher).first
    @event = Auditors::GradeChange.record(@submission)
  end

  context "nominal cases" do
    it "should include event" do
      Auditors::GradeChange.for_assignment(@assignment).paginate(:per_page => 5).should include(@event)
      Auditors::GradeChange.for_course(@course).paginate(:per_page => 5).should include(@event)
      Auditors::GradeChange.for_root_account_student(@account, @student).paginate(:per_page => 5).should include(@event)
      Auditors::GradeChange.for_root_account_grader(@account, @teacher).paginate(:per_page => 5).should include(@event)
    end
  end

  describe "options forwarding" do
    before do
      record = Auditors::GradeChange::Record.new(
        'submission' => @submission,
        'created_at' => 1.day.ago
      )
      @event2 = Auditors::GradeChange::Stream.insert(record)
    end

    it "should recognize :oldest" do
      page = Auditors::GradeChange.for_assignment(@assignment, oldest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event)
      page.should_not include(@event2)

      page = Auditors::GradeChange.for_course(@course, oldest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event)
      page.should_not include(@event2)

      page = Auditors::GradeChange.for_root_account_student(@account, @student, oldest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event)
      page.should_not include(@event2)

      page = Auditors::GradeChange.for_root_account_grader(@account, @teacher, oldest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event)
      page.should_not include(@event2)
    end

    it "should recognize :newest" do
      page = Auditors::GradeChange.for_assignment(@assignment, newest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event2)
      page.should_not include(@event)

      page = Auditors::GradeChange.for_course(@course, newest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event2)
      page.should_not include(@event)

      page = Auditors::GradeChange.for_root_account_student(@account, @student, newest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event2)
      page.should_not include(@event)

      page = Auditors::GradeChange.for_root_account_grader(@account, @teacher, newest: 12.hours.ago).paginate(:per_page => 2)
      page.should include(@event2)
      page.should_not include(@event)
    end
  end
end
