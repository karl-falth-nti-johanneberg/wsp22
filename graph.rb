require 'Scruffy'

graph = Scruffy::Graph.new()

graph.add(:bar, [0,1,2,3,4,5,6,7,8,9,10])

graph.render(:as => "PNG", :to => "./graph.png")