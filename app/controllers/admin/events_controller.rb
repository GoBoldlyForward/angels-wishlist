# frozen_string_literal: true

module Admin
  class EventsController < BaseController
    before_action :set_event, only: %i[show edit update]

    def index
      @events = Event.where(organization: current_chapter).newest_first
    end

    def show
    end

    def new
      @form = EventForm.for_new_event(current_chapter)
    end

    def create
      @form = EventForm.for_new_event(current_chapter, event_params)

      if @form.save
        redirect_to admin_event_path(@form.record), notice: "#{@form.name} is set up."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @form = EventForm.new(@event)
    end

    def update
      @form = EventForm.new(@event, event_params)

      if @form.save
        redirect_to admin_event_path(@event), notice: "Saved.", alert: @form.cap_warning
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_event
      @event = Event.where(organization: current_chapter).friendly.find(params[:id])
    end

    def event_params
      params.expect(event: [ :name, :opened_at, :closes_at, :payout_at, :per_child_cap_in_dollars, :love_box_edited,
                             { love_box_groups: [ %i[id label options picks hint large_household_only asks_count] ] } ])
    end
  end
end
