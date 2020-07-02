# -*- coding: utf-8 -*-
from ansible.utils.display import Display


class FilterModule(object):
    def filters(self):
        return {"deprecate_me": self.warn_filter}

    def warn_filter(self, message, **kwargs):
        Display().deprecated(message)
        return message
