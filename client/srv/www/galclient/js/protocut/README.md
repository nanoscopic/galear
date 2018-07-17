# protocut
Minimal JS library based loosely on prototypejs

This library is meant as an extremely bare bones replacement for heavyweight libraries such as jQuery and PrototypeJS. The code contained in this library is based directly on PrototypeJS ( some code is copied outright ).

The library is currently composed of 3 files splitting the content into sections by use. The three sections are base, ajax, and dom. 

Base is just a simple set of functions to enable the creation of classes and binding of scope to functions. All extra frills have been removed to make it as efficient as possible.

Ajax are basic functions to enable the use of Ajax file loading. It supports loading JSON as well as XML content. XML content is loaded and parsed in such as way that it can be easily accessed as a nested structure like JSON rather than having to use overly verbose XML navigation functions.

DOM contains helper functions to quickly and easily create various DOM nodes, as well as a variety of functions to search / navigate the DOM. It is designed to use very short names that can be remembered easily so that code written against the library is small and easy to write.
