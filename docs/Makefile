
NODES=nodes.json
GENERATOR=./generate_docs.py

docs: audio.html

audio.html: $(NODES) $(GENERATOR)
	$(GENERATOR) < $(NODES) > audio.html


