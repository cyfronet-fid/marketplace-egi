# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jira::CommentCreated do
  let(:project_item) { create(:project_item, status: :registered) }

  it "creates new project_item change" do
    expect { described_class.new(project_item, comment(message: "msg", id: 123)).call }.
      to change { project_item.order_changes.count }.by(1)
  end

  it "sets message and comment id" do
    described_class.new(project_item, comment(message: "msg", id: "123")).call
    last_change = project_item.order_changes.last

    expect(last_change.message).to eq("msg")
    expect(last_change.iid).to eq(123)
  end

  it "does not change project_item status" do
    described_class.new(project_item, comment(message: "msg", id: "123")).call

    expect(project_item).to be_registered
    expect(project_item.order_changes.last).to be_registered
  end

  it "does not duplicate project_item changes" do
    # Such situation can occur when we are sending question from MP to jira.
    # Than jira webhood with new comment is triggered.
    project_item.new_change(message: "question", iid: 321)

    expect do
      described_class.new(project_item, comment(message: "question", id: "321")).call
    end.to_not change { project_item.order_changes.count }
  end

  def comment(message:, id:, author: "non@existing.pl")
    { "body" => message, "id" => id, "emailAddress" => author }
  end
end
