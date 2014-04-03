require 'spec_helper'

describe "The root page", :type => :feature do
  it "should display a list of jobs" do
    QC.enqueue "Class.method"
    visit '/'
    page.should have_content "Class.method"
  end

  it "should allow the user to switch between job queues" do
    QC.enqueue "Default.method"
    QC::Queue.new("named_queue").enqueue("Named.method")

    visit "/"
    page.should have_content "Default.method"
    page.should have_content "Named.method"

    click_link "named_queue"
    page.should have_content "Named.method"
    page.should have_no_content "Default.method"
  end

  it "should allow the user to delete jobs" do
    QC.enqueue "Class.method"
    visit "/"

    page.should have_content "Class.method"
    click_button "Destroy Job"
    page.should have_no_content "Class.method"
  end

  it "should allow the user to unlock jobs" do
    QC.enqueue "Class.method"
    execute_sql "UPDATE queue_classic_jobs SET locked_at = now()"

    visit '/'

    page.should have_button "Unlock Job"
    click_button "Unlock Job"
    page.should have_no_button "Unlock Job"
    execute_sql("SELECT * FROM queue_classic_jobs WHERE locked_at IS NOT NULL").should == []
  end

  it "should allow the user to destroy all jobs" do
    2.times { QC.enqueue "Class.method" }
    visit "/"
    click_button "Destroy All"
    page.should have_no_content "Class.method"
    execute_sql("SELECT * FROM queue_classic_jobs").should == []
  end

  it "should allow the user to page back and forth between results" do
    101.times { |i| QC.enqueue "Class.method#{i}" }
    visit "/"
    page.should have_content "Class.method100"
    page.should have_content "Class.method51"
    page.should have_no_content "Class.method50"

    click_link "Next Page"
    page.should have_content "Class.method50"
    page.should have_content "Class.method1"
    page.should have_no_content "Class.method0"

    click_link "Next Page"
    page.should have_no_link "Next Page"
    page.should have_no_content "Class.method1"
    page.should have_content "Class.method0"

    click_link "Previous Page"
    page.should have_content "Class.method1"
  end

  it "should allow the user to stay on the same queue while paginating" do
    200.times { |i| QC::Queue.new(i.even?.to_s).enqueue "Class.method#{i}" }
    visit "/"
    click_link "true"
    page.should have_content "Class.method198"
    page.should have_no_content "Class.method197"
    page.should have_content "Class.method196"

    click_link "Next Page"
    page.should have_content "Class.method98"
    page.should have_content "Class.method96"
    page.should have_no_content "Class.method97"
  end
end
