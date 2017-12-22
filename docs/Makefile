
NODES=nodes.json
GENERATOR=./generate_docs.py

docs: audio.html control.html

audio.html: $(NODES) $(GENERATOR)
	$(GENERATOR) audio < $(NODES) > audio.html

control.html: $(NODES) $(GENERATOR)
	$(GENERATOR) control < $(NODES) > control.html


