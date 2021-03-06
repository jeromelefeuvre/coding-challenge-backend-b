require 'csv'
require 'geocoder'
require 'active_support/all'

class Suggestion
  attr_accessor :cities
  attr_accessor :q, :latitude, :longitude, :limit

  def initialize(cities, params = {})
    params.symbolize_keys!

    @cities    = cities
    @q         = params.fetch(:q, nil)
    @latitude  = params.fetch(:latitude, nil)
    @longitude = params.fetch(:longitude, nil)
    @limit     = params.fetch(:limit, 0).to_i
  end

  def results
    results = search_according_query.collect do |city|
      {
        :name      => city.complete_name,
        :latitude  => city.latitude,
        :longitude => city.longitude,
        :score     => score_for(city),
      }
    end

    results.sort_by{ |x| [-x[:score], x[:name]] }[0..limit-1]
  end

  def errors
    return 'query is mandatory!' if q.blank?

    return 'lat or long missing' if lat_or_long_missing?
  end

  def errors?
    errors.present?
  end

  private

  def query_parameterize
    I18n.transliterate q
  end

  def search_according_query
    cities.select{ |city| city.ascii.match(/^#{query_parameterize}/i) }
  end

  def lat_long_present?
    latitude && longitude
  end

  def lat_or_long_missing?
    return true if latitude && longitude.blank?
    return true if longitude && latitude.blank?
  end

  def score_for(city)
    scores = [score_by_length_for(city)]
    scores << score_by_population_for(city)
    scores << score_by_distance_for(city) if lat_long_present?

    calculate_score_with(scores)
  end

  def score_by_length_for(city)
    Float(q.length) / city.ascii.length
  end

  def score_by_population_for(city)
    1 - Float(ParseDatas::MAX_POPULATIONS)/city.population
  end

  def score_by_distance_for(city)
    1 - distance_for(city) / (Math::PI*Geocoder::Calculations::EARTH_RADIUS)
  end

  def distance_for(city)
    Geocoder::Calculations.distance_between([latitude, longitude], [city.latitude.to_f, city.longitude.to_f], :units => :km)
  end

  def calculate_score_with(scores)
    (scores.inject(:+) / scores.length).round(1)
  end
end
