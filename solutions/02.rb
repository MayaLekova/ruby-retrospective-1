class Song
  def initialize(spec)
    @name, @artist, genre_spec, tag_spec = spec.split('.').map { |s| s.strip }
    @genre, @subgenre = genre_spec.split(',').map { |s| s.strip }
    @tags = [@genre.downcase]
    @subgenre and @tags.push @subgenre.downcase
    tag_spec and tag_spec.lines(',') { |tag| @tags.push tag.strip.delete(',') }
  end
  
  def add_tags(tags)
    (@tags += tags).uniq!
  end
  
  attr_reader :name, :artist, :genre, :subgenre, :tags

  def matches?(criteria)
    match_tags criteria[:tags] and 
    match_name criteria[:name] and
    match_artist criteria[:artist] and
    match_filter criteria[:filter]
  end
  
  def match_tags(tags)
    return true unless tags
    
    negative = tags.select { |tag| tag.end_with? '!' }
    positive = tags - negative
    
    negative = negative.map{ |str| str.delete '!' }
    
    (@tags & negative).empty? and (@tags & positive) == positive
  end
  
  def match_name(name)
    !name or @name == name
  end

  def match_artist(artist)
    !artist or @artist == artist
  end
  
  def match_filter(pred)
    !pred or pred.call self
  end
end

class Collection
  def initialize(songs_as_string, artist_tags)
    @songs = []
    songs_as_string.lines { |line| @songs.push Song.new line }
    artist_tags.map { |entry| add_to_songs entry }
  end
  
  def add_to_songs(tags)
    @songs.map { |song| song.add_tags tags[1] if song.artist == tags[0] }
  end
  
  def find(criteria)
    @songs.select { |s| s.matches? criteria }
  end
end
